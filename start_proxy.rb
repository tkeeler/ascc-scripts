# Copyright 2011 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"). You
# may not use this file except in compliance with the License. A copy of
# the License is located at
#
#     http://aws.amazon.com/apache2.0/
#
# or in the "license" file accompanying this file. This file is
# distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF
# ANY KIND, either express or implied. See the License for the specific
# language governing permissions and limitations under the License.

require 'rubygems'
require 'yaml'
require 'open-uri'
require 'aws-sdk'

image_id = "ami-1b814f72"
local_ip = open('http://169.254.169.254/latest/meta-data/local-ipv4').read
AWS.config(:access_key_id => '', :secret_access_key => '')

puts "Logging in to EC2"
ec2 = AWS::EC2.new

key_pair = ec2.key_pairs['windows-keys2']
security_group = ec2.security_groups['sg-5ae1a233']


startup_script = "
#!/bin/bash
yum -y install varnish

/etc/init.d/varnishlog start
/etc/init.d/varnishncsa start

ulimit -n 131072
ulimit -l 82000

varnishd -a :80 -b #{local_ip}:80 -t 2 -w 5,1000 -u varnish -g varnish -s file,/var/lib/varnish/varnish_storage.bin,1G
"



puts "Creating Amazon Linux instance"
instance = ec2.instances.create(:image_id => image_id, :key_pair => key_pair, :security_groups => security_group, :instance_type => 'm1.large', :user_data => startup_script)

puts "Created. Waiting for instance to start"
while instance.status == :pending
  print "."
  $stdout.flush
  sleep 1
end

puts

instance.tag('Name', :value => 'Proxy Server')

puts "Instance #{instance.id} launched, status: #{instance.status}"

puts "Public IP:"
puts "#{instance.dns_name}"

puts "Logging in to ELB"
ebs = AWS::ELB.new
stream_load_balancer=ebs.load_balancers['Stream']

puts "Adding new proxy to Load Balancer"
stream_load_balancer.instances.register(instance)

puts "Now load balancing over #{stream_load_balancer.instances.count} instances"
