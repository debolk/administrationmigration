# Load gems needed to talk to blip and operculum
require 'json'
require 'net/http'
require 'csv'

# Open needed files
$problems = File.open('problems.log', 'w')

# Open the blip API $index /persons
blip = JSON.parse(Net::HTTP.get_response(URI.parse('https://people.i.bolkhuis.nl/persons?access_token=verysecret')).body)

#
# Some useful functions
#

# POST to a URL with a payload, returning the result
def post(url, payload)
  url = URI.parse(url)
  http = Net::HTTP.new(url.host, url.port)
  http.use_ssl = true
  request = Net::HTTP::Post.new(url.path+'?access_token=verysecret')
  request.content_type = 'application/json'
  request.body = JSON.generate(payload)
  response = http.start {|http| http.request(request) }
  begin
    return JSON.parse(response.body)
  rescue
    # Log as a problematic case with rule number and line
    $problems.write "#{$index}, #{payload}, #{response.body}\n"
    return nil
  end
end

# PUT to a URL with a payload, returning the result
def put(url, payload)
  url = URI.parse(url)
  http = Net::HTTP.new(url.host, url.port)
  http.use_ssl = true
  request = Net::HTTP::Put.new(url.path+'?access_token=verysecret')
  request.content_type = 'application/json'
  request.body = JSON.generate(payload)
  response = http.start {|http| http.request(request) }
  begin
    return JSON.parse(response.body)
  rescue
    # Log as a problematic case with rule number and line
    $problems.write "#{$index}, #{payload}, #{response.body}\n"
    return nil
  end
end

# PATCH to a URL with a payload, returning the result
def patch(url, payload)
  url = URI.parse(url)
  http = Net::HTTP.new(url.host, url.port)
  http.use_ssl = true
  request = Net::HTTP::Patch.new(url.path+'?access_token=verysecret')
  request.content_type = 'application/json'
  request.body = JSON.generate(payload)
  response = http.start {|http| http.request(request) }
  begin
    return JSON.parse(response.body)
  rescue
    # Log as a problematic case with rule number and line
    $problems.write "#{$index}, #{payload}, #{response.body}\n"
    return nil
  end
end

# Creates a new user
def create(params, membership)
  # Send payload to blip
  blip = post('https://people.i.bolkhuis.nl/persons', {
    initials: (params[4].nil? ? params[5][0] : params[4].tr('^a-zA-Z', '')),
    firstname: params[5],
    lastname: [params[6], params[7]].reject{|e| e.nil? or e.empty?}.join(' '),
    email: params[3],
    gender: params[9] == 'Vrouw' ? 'F' : 'M',
    phone: params[14],
    mobile: params[2],
    phone_parents: params[24],
    address: [params[10], params[11], params[12]].join(' '),
    dateofbirth: params[15],
    membership: membership,
  })

  # Grab uid
  unless blip == nil
    uid = blip['uid']

    # Send payload to operculum
      put("https://operculum.i.bolkhuis.nl/person/#{uid}", {
      nickname: params[8],
      study: params[16],
      alive: params[17].nil?,
      inauguration: params[25],
      resignation_letter: params[26],
      resignation: params[27],
    })
  end
end

# Updates an existing user
def update(uid, params)
  # Send payload to blip
  patch("https://people.i.bolkhuis.nl/persons/#{uid}", {
    initials: (params[4].nil? ? params[5][0] : params[4].tr('^a-zA-Z', '')),
    email: params[3],
    gender: params[9] == 'Vrouw' ? 'F' : 'M',
    phone: params[14],
    mobile: params[2],
    phone_parents: params[24],
    address: [params[10], params[11], params[12]].join(' '),
    dateofbirth: params[15],
  })

  # Send payload to operculum
  put("https://operculum.i.bolkhuis.nl/person/#{uid}", {
    nickname: params[8],
    study: params[16],
    alive: params[17].nil?,
    inauguration: params[25],
    resignation_letter: params[26],
    resignation: params[27],
  })
end

#
# The actual processing
#

# Read every line  of the Excel
$index = 0
CSV.foreach("data.csv") do |input|
  # Increment the $index
  $index += 1

  # Skip the first line (headers)
  if $index == 1
    next
  end

  # Determine what to do based on the status of the member
  case input[1].downcase
  when 'gewoon lid'
    group = 'lid'
  when 'in lid-afprocedure'
    group = 'lid'
  when 'kandidaat-lid'
    group = 'kandidaatlid'
  when 'lid van verdienste'
    group = 'lidvanverdienste'
  when 'oud-lid'
    group = 'oudlid'
  else
    next # Skip this member, do not save to LDAP
  end

  # Find if member exists
  found = false
  count = 0
  uid = nil
  blip.each do |entry|
    if entry['name'].downcase === input[0].downcase
      count += 1 
      uid = entry['uid']
    end
  end

  # Determine what to do
  if count === 0
    # Create new person
    create(input, group)
  elsif count === 1
    # Update existing person
    
    # Testcondition: only apply to Max and Jakob
    if uid == 'max' or uid == 'jakob'
      update(uid, input)
    end
  else
    # Log as a problematic case with rule number and line
    $problems.write "#{$index}, #{input[0]}\n"
  end
end
