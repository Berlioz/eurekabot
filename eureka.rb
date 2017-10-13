require 'discordrb'
require 'open-uri'
require 'uri'
require 'json'
require 'open-uri'
require 'nokogiri'
require 'pry'

$last_charname = nil
$last_servers = nil

ZONES = {
	4 => [1034, 1035, 1038],			# Stormblood Primals
	6 => [17],							# A4S
	9 => [25],							# A8S
	13 => [34, 35, 36, 37],				# A9-A12S
	15 => [1036, 1037],					# Susano and Lakshmi
	17 => [42, 43, 44, 45, 46]			# O1S-O4S
}

ENCOUNTERS = {
	42 => "O1S", 43 => "O2S", 44 => "O3S", 45 => "Exfaust", 46 => "O4S", 1036 => "Partydad", 1037 => "Snakemom", 1038 => "Dragondad",
	34 => "A9S", 35 => "A10S", 36 => "A11S", 37 => "A12S", 25 => "A8S", 17 => "A4S", 1034 => "Sophia", 1035 => "Zurvan"
}

CLASSES = {
	"Astrologian" => "**AST**",
	"Bard" => "**BRD**",
	"BlackMage" => "**BLM**", 
	"DarkKnight" => "**DRK**", 
	"Dragoon" => "**DRG**", 
	"Machinist" => "**MCH**", 
	"Monk" => "**MNK**", 
	"Ninja" => "**NIN**", 
	"Paladin" => "**PLD**", 
	"Scholar" => "**SCH**", 
	"Summoner" => "**SMN**", 
	"Warrior" => "**WAR**", 
	"WhiteMage" => "**WHM**", 
	"RedMage" => "**RDM**", 
	"Samurai" => "**SAM**"
}

EMOJI = {
	"Astrologian" => "<:astbot:362031567578726412>",
	"Bard" => "<:brdbot:362031567851356160>",
	"BlackMage" => "<:blmbot:362031567562080268>", 
	"DarkKnight" => "<:drkbot:362031567994093568>", 
	"Dragoon" => "<:drgbot:362031567457222680>", 
	"Machinist" => "<:mchbot:362031567624732696>", 
	"Monk" => "<:mnkbot:362031567855550465>", 
	"Ninja" => "<:ninbot:362031567977316352>", 
	"Paladin" => "<:pldbot:362031568539222027>", 
	"Scholar" => "<:schbot:362031567687778319>", 
	"Summoner" => "<:smnbot:362031568128180224>", 
	"Warrior" => "<:warbot:362031567670870018>", 
	"WhiteMage" => "<:whmbot:362031568010739722>", 
	"RedMage" => "<:rdmbot:362031567679389737>", 
	"Samurai" => "<:sambot:362031567993831424>"
}

bot = Discordrb::Commands::CommandBot.new token: File.read('token'), client_id: 361970591021924352, prefix: '!'

bot.command :logs do |event, *args|
	respondLogs(event, [15, 17], args)
end

bot.command :esports do |event, *args|
	respondLogs(event, [17], args)
end

bot.command :zsports do |event, *args|
	respondLogs(event, [4, 6, 9, 13], args)
end

bot.command :bsports do |event, *args|
	respondLogs(event, [], args)
end

bot.command :ls do |event, *args|
	fname = args[0]
	lname = args[1]
	dc = args[2] || "Primal"
	respondLodestone(event, fname + " " + lname, dc)
end

bot.command :xlogs do |event, *args|
	i = (args[0]) ? (args[0].to_i - 1) : 0
	event << "Quick lookup for *#{$last_charname}* (#{$last_servers[i]}):"
	respondLogs(event, [15, 17], $last_charname.split + [$last_servers[i]])
end

bot.command :math do |event, *args|
	if Random.rand(2) == 0
		event << "You suffer the effect of Low Arithmeticks."
	else
		event << "You suffer the effect of High Arithmeticks."
	end
	return nil
end

bot.command :help do |event, *args|
	p event.server.id
	event << "**!logs** *name* *server*: gets data for all current patch content."
	event << "**!esports** *name* *server*: gets data for all current raid content."
	event << "**!bsports** *name* *server*: gets data for previous patch raid content."
	event << "**!zsports** *name* *server*: gets data for selected encounters in previous expansions."
	event << "**!ls** *name* *dc*: find charcters in a datacenter with a name, and their 70 classes."
	event << "**!xlogs**: shortcut to make a !logs request with the top result of the last !ls request"
	event << "**!xlogs** *n*: shortcut to make a !logs request with the Nth result of the last !ls request, counting from 1."
	event << "*server* defaults to excalibur. *dc* defaults to primal. xlogs won't work for JP servers."
end

def respondLogs(event, zones, args)
	fname = args[0]
	lname = args[1]
	server = args[2] || 'Excalibur'
	scrub = true
	begin
		raw = analyze(fname + " " + lname, zones, server)
	rescue Exception => e
		p e
		p e.backtrace
		event << "FFlogs request errored; charactername/server are probably wrong"
		raw = {}
		scrub = false
	end

	if raw["hidden"]
		event << "User manually disabled their FFlogs. They're probably garbage and sensitive about it."
		return
	end

	raw.each do |cid, data|
		if data.length > 0
			scrub = false
			line = ["#{displayClass(event, cid)} "]
			data.each do |eid, record|
				line << "**#{ENCOUNTERS[eid]}** #{record[:dps]} (#{record[:medpct]}%/#{record[:maxpct]}%),"
			end
			event << line.join(" ")[0..-2]
		end
	end
	if scrub
		event << "FFlogs did not error, but also did not return any results."
	end
end

def respondLodestone(event, name, datacenter)
	begin
		data = lodestone(event, name, datacenter)
	rescue Exception => e
		event << "Something errored out, failure has been logged."
		p e
		p e.backtrace
		return nil
	end

	if data.length > 0
		$last_charname = name
		$last_servers = data.keys
		event << "Results for *#{name}* on #{datacenter}:"
	else
		event << "No results found..."
	end

	data.each do |k, v|
		if v.length > 0
			event << "**#{k}**: #{v.join(', ')}"
		else
			event << "**#{k}**: no jobs at level cap"
		end
	end

	return nil
end

# GET and JSON-encode a single FFlogs metrics request for a character + fight combination
def fflogs_fight(name, server, zone, encounter)
	# https://www.fflogs.com:443/v1/parses/character/Mistel%20Aventice/Excalibur/NA?zone=17&encounter=42&api_key=d111a2f951c186357796eca246ca2640
	region = getRegion(server)
	uri = URI.parse(URI::encode("https://www.fflogs.com:443/v1/parses/character/" + name + "/" + server + "/" + region))
	params = {:api_key => "d111a2f951c186357796eca246ca2640", :zone => zone, :encounter => encounter}
	uri.query = URI.encode_www_form( params )
	p "GET " + uri.to_s
	return JSON.parse(uri.open.read)	
end

# Given a character and raid tier, return performance data for that tier for each class
# Example: {"Astrologian"=>{42=>{:dps=>1625.87, :maxpct=>89, :medpct=>74}, 43=>{:dps=>1597.98, :maxpct=>86, :medpct=>79}, "Bard"=>{}}
def analyze(name, query_zones, server)
	out = {}
	CLASSES.keys.each do |c|
		out[c] = {}
	end
	ZONES.each do |zone, encounters|
		next unless query_zones.include?(zone)
		encounters.each do |eid|
			response = fflogs_fight(name, server, zone, eid)
			return response if response.first == ["hidden", true]
			next if response.count == 0
			specs = response.first["specs"]
			specs.each do |spec|
				classname = spec["spec"]
				dps = spec["best_persecondamount"]
				maxpct = spec["best_historical_percent"]
				medpct = spec["historical_median"]
				out[classname][eid] = {:dps => dps, :maxpct => maxpct, :medpct => medpct}
			end
		end
	end

	return out
end

# Given a character name and data center, return all exact match characters with world and 70 jobs
# example: {"Excalibur" => ":pld:, :sch:", "Hyperion" => ":blm:"}
def lodestone(event, name, dc)
	urlname = name.tr(' ', '+')
	urldc = "_dc_" + dc
	doc = Nokogiri::HTML(open("https://na.finalfantasyxiv.com/lodestone/character/?q=#{urlname}&worldname=#{urldc}"))

	out = {}
	characters = doc.css('.entry').select{|e| e.to_s.include?("entry__name")}
	# I DONT KNOW XPATH
	characters = characters.select{|c| c.children.children.first.children.first.attributes["alt"].value == name}
	characters.each do |c|
		world = c.children.children[1].children[1].children[0].to_s
    	# ok i know a little xpath
		q = "https://na.finalfantasyxiv.com" + c.xpath("a").first.attributes["href"]
		p "GET " + q
		cdoc = Nokogiri::HTML(open(q))
		capped = []

		cdoc.xpath('//li').select{|e| e.to_s.include?("character__job__level")}.select{|j| j.xpath("div[@class='character__job__level']").first.children.to_s == "70"}.each do |j|
			begin
				jobname = j.xpath("div[@class='character__job__name js__tooltip']").first.children.first.to_s
				displayname = displayClass(event, jobname.tr(' ',''))
				capped << displayname if displayname
		rescue Exception => e
    			# some DoHs have weirdly formed HTML, probably, maybe
			end
		end

		out[world] = capped
	end

	return out
end

# TODO: display text in situations where discord emoji are unavailable	
def displayClass(event, classname)
	serverid = event.server.id
	return EMOJI[classname]
end

AETHER = ['adamantoise', 'balmung', 'cactuar', 'coeurl', 'faerie', 'gilgamesh', 'goblin', 'jenova', 'mateus', 'midgardsormr', 'sargatanas', 'siren', 'zalera']
PRIMAL = ['behemoth', 'brynhildr', 'diabolos', 'excalibur', 'exodus', 'famfrit', 'hyperion', 'lamia', 'leviathan', 'malboro', 'ultros']
CHAOS = ['cerberus', 'lich', 'louisoix', 'moogle', 'odin', 'omega', 'phoenix', 'ragnarok', 'shiva', 'zodiark']
ELEMENTAL = ['aegis', 'atomos', 'carbuncle', 'garuda', 'gungnir', 'kujata', 'ramuh', 'tonberry', 'typhon', 'unicorn']
GAIA = ['alexander', 'bahamut', 'durandal', 'fenrir', 'ifrit', 'ridill', 'tiamat', 'ultima', 'valefor', 'yojimbo', 'zeromus']
MANA = ['anima', 'asura', 'belias', 'chocobo', 'hades', 'ixion', 'mandragora', 'masamune', 'pandemonium', 'shinryu', 'titan']
def getRegion(server)
	server = server.downcase
	if (AETHER + PRIMAL).include?(server)
		return 'NA'
	elsif CHAOS.include?(server)
		return 'EU'
	elsif (ELEMENTAL + GAIA + MANA).include?(server)
		return 'JP'
	else
		return nil
	end
end

bot.run