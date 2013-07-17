# Load gems
require 'json'
require 'net/http'

# Open the needed files
ldap = File.open('output.ldif', 'w')
mysql = File.open('output.sql', 'w')
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

  # Determine what to do based on the status of the member
  case input[1].downcase
  when '"gewoon lid"'
    group = 'gewoonlid'
  when '"in lid-afprocedure"'
    group = 'lid'
  when '"kandidaat-lid"'
    group = 'kandidaatlid'
  when '"lid van verdienste"'
    group = 'lidvanverdienste'
  when '"oud-lid"'
    group = 'oudlid'
  else
    next # Skip this member, do not save to LDAP
  end

  # Find if member exists
  found = false
  count = 0
  blip.each do |entry|
    count += 1 if '"'+(entry['name'].downcase)+'"' === input[0].downcase
  end

  # Determine what to do
  if count === 0
    # Create new person
    ldap.write "#{index}, #{input[0]}\n"
  elsif count === 1
    # Update existing person
    mysql.write "#{index}, #{input[0]}\n"
  else
    # Log as a problematic case with rule number and line
    problems.write "#{index}, #{input[0]}\n"
  end
end
# zoek hun volledige naam
# if count == 1 {
# update die persoon
# }
# elseif count === 0 {
# maak nieuwe persoon
# else {
# log als probleemgeval met (regelnummer en naam)
# }

  # # Construct new entries
  # ldap_data = {
  #   mobile: input[2],
  #   email: input[3],
  #   initials: input[4],
  #   givenname: input[5],
  #   sn: [input[6], input[7]].reject{|e|e.empty?}.join(' '),
  #   gender: input[9] == 'Man' ? 'M' : 'F',
  #   address: [input[10], input[11], input[12]].join(' '),
  #   phone: input[14],
  #   birthdate: input[15],
  # }
  # mysql_data = {
  #   study: input[16],
  #   alive: !input[17].empty?,
  #   phone_parents: input[24],
  #   inauguration: input[25],
  #   resignation_letter: input[26],
  #   resignation: input[27],    
  # }



  # # Write to output
  # ldap.write ldap_data
  # mysql.write mysql_data
