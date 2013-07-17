# Guard to prevent accidental execution
exit

# Load gems needed to talk to blip and operculum
require 'json'
require 'net/http'

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
  JSON.parse(response.body)
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
  JSON.parse(response.body)
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
  JSON.parse(response.body)
end

# Creates a new user
def create(params, membership)
  # Send payload to blip
  blip = post('https://people.i.bolkhuis.nl/persons', {
    initials: params[4],
    firstname: params[5],
    lastname: [params[6], params[7]].reject{|e|e.empty?}.join(' '),
    email: params[3],
    gender: params[9] == 'Vrouw' ? 'M' : 'F',
    phone: params[14],
    mobile: params[2],
    phone_parents: params[24],
    address: [params[10], params[11], params[12]].join(' '),
    dateofbirth: params[15],
    membership: membership,
  })

  # Grab uid
  uid = blip['uid']
  
  # Send payload to operculum
  put("https://operculum.i.bolkhuis.nl/persons/#{uid}", {
    nickname: params[8],
    study: params[16],
    alive: !params[17].empty?,
    inauguration: params[25],
    resignation_letter: params[26],
    resignation: params[27],
  })
end

# Updates an existing user
def update(uid, params)
  # Send payload to blip
  put("https://people.i.bolkhuis.nl/persons/#{uid}", {
    initials: params[4],
    email: params[3],
    gender: params[9] == 'Vrouw' ? 'M' : 'F',
    phone: params[14],
    mobile: params[2],
    phone_parents: params[24],
    address: [params[10], params[11], params[12]].join(' '),
    dateofbirth: params[15],
  })

  # Send payload to operculum
  put("https://operculum.i.bolkhuis.nl/persons/#{uid}", {
    nickname: params[8],
    study: params[16],
    alive: !params[17].empty?,
    inauguration: params[25],
    resignation_letter: params[26],
    resignation: params[27],
  })
end

#
# The actual processing
#

# Open needed files
problems = File.open('problems.log', 'w')

# Open the blip API index /persons
blip = JSON.parse(Net::HTTP.get_response(URI.parse('https://people.i.bolkhuis.nl/persons?access_token=verysecret')).body)

# Read every line
index = 0
IO.foreach "data.csv" do |line|
  # Increment the index
  index += 1

  # Skip the first line (headers)
  if index == 1
    next
  end

  # Read the input
  input = line.split(';')

  # Remove parentheses
  input.each do |e|
    if e.length > 1
      e[0] = ''
      e[-1] = ''
    end
  end

  # Determine what to do based on the status of the member
  case input[1].downcase
  when 'gewoon lid'
    group = 'gewoonlid'
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
    update(uid, input)
  else
    # Log as a problematic case with rule number and line
    problems.write "#{index}, #{input[0]}\n"
  end
end
