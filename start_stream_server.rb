require 'rubygems'
require 'yaml'
require 'open-uri'
require 'aws-sdk'

AMAZON_IMAGE_ID = "ami-9e53f7f7"
KEY_PAIR_NAME = "ddrinka"
SECURITY_GROUP_ID = "sg-8ad89be3"
INSTANCE_SIZE = "m1.large"
ELASTIC_IP = "23.23.188.171"

`echo "Starting up Windows Stream server" | logger -t encode_script`


local_ip = open('http://169.254.169.254/latest/meta-data/local-ipv4').read
AWS.config(:access_key_id => '', :secret_access_key => '')

puts "Logging in to EC2"
ec2 = AWS::EC2.new

key_pair = ec2.key_pairs[KEY_PAIR_NAME]
security_group = ec2.security_groups[SECURITY_GROUP_ID]

puts "Creating Amazon Linux instance"
instance = ec2.instances.create(
	:image_id => AMAZON_IMAGE_ID,
	:key_pair => ec2.key_pairs[KEY_PAIR_NAME],
	:security_groups => ec2.security_groups[SECURITY_GROUP_ID],
	:instance_type => INSTANCE_SIZE,
  	:instance_initiated_shutdown_behavior => 'terminate',
	:block_device_mappings => {'xvdb' => 'ephemeral0'}
)

puts "Created. Waiting for instance to start"
while !instance.exists? || instance.status == :pending
  print "."
  $stdout.flush
  sleep 1
end

puts

instance.tag('Name', :value => 'Windows Media Services')
instance.associate_elastic_ip(ec2.elastic_ips[ELASTIC_IP])

puts "Instance #{instance.id} launched, status: #{instance.status}"

puts "Public IP:"
puts "#{instance.dns_name}"
`echo "Windows Stream instance created. IP: #{instance.dns_name}" | logger -t encode_script`
