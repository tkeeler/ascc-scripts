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
require 'aws-sdk'

AWS.config(:access_key_id => '', :secret_access_key => '')

puts "Logging in to EC2"
ec2 = AWS::EC2.new

images = ec2.images.tagged("Encoder")
if(images.count == 0)
  puts "No image tagged with 'Encoder' found. Exiting"
  exit -1
end

image = images.first
key_pair = ec2.key_pairs['windows-keys2']
security_group = ec2.security_groups['sg-5ae1a233']

puts "Creating instance"
instance = image.run_instance(:key_pair => key_pair, :security_groups => security_group, :instance_type => 'c1.xlarge')

puts "Created. Waiting for instance to start"
while instance.status == :pending
  print "."
  $stdout.flush
  sleep 1
end

puts

instance.tag('Name', :value => 'Linux Encode Server')

puts "Instance #{instance.id} launched, status: #{instance.status}"

puts "Public IP:"
puts "#{instance.dns_name}"
