# Open the target file
ldap = File.open('output.ldif', 'w')
mysql = File.open('output.sql', 'w')

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
  when 'nooit lid geworden', 'ex-lid', 'onbekend'
    next # Do not save to LDAP
  end

  # Construct new entries
  ldap_data = {
    mobile: input[2],
    email: input[3],
    initials: input[4],
    givenname: input[5],
    sn: [input[6], input[7]].reject{|e|e.empty?}.join(' '),
    gender: input[9] == 'Man' ? 'M' : 'F',
    address: [input[10], input[11], input[12]].join(' '),
    phone: input[14],
    birthdate: input[15],
  }
  mysql_data = {
    study: input[16],
    alive: !input[17].empty?,
    phone_parents: input[24],
    inauguration: input[25],
    resignation_letter: input[26],
    resignation: input[27],    
  }

  # Determine 

  # Write to output
  ldap.write ldap_data
  mysql.write mysql_data
end