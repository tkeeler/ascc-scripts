require 'rubygems'
require 'yaml'
require 'open-uri'
require 'aws-sdk'

class BitrateParam
  attr_accessor :bitrate
  attr_accessor :x_resolution
  attr_accessor :y_resolution
  attr_accessor :audio_type
  def initialize(bitrate, x_resolution, y_resolution, audio_type)
    @bitrate=bitrate
    @x_resolution=x_resolution
    @y_resolution=y_resolution
    @audio_type=audio_type
  end
end

AMAZON_IMAGE_ID = "ami-e965ba80"
KEY_PAIR_NAME = "ddrinka"
SECURITY_GROUP_ID = "sg-5ae1a233"
INSTANCE_SIZE = "cc2.8xlarge"

INCOMING_BITRATE = "828k"
OUTGOING_PARAMS =[
  BitrateParam.new(230, 426, 240, "high")
]


if(ARGV.size != 2)
  puts "Usage: start_encode_server.rb <INCOMING_PUB_POINT> <OUTGOING_PUB_POINT>"
  exit 1
end

(INCOMING_PUB_POINT, OUTGOING_PUB_POINT) = ARGV

`echo "Encode server starter script running. Incoming pub point: #{INCOMING_PUB_POINT} outgoing pub point: #{OUTGOING_PUB_POINT}" | logger -t encode_script`


local_ip = open('http://169.254.169.254/latest/meta-data/local-ipv4').read
AWS.config(:access_key_id => '', :secret_access_key => '')

puts "Logging in to EC2"
ec2 = AWS::EC2.new

key_pair = ec2.key_pairs[KEY_PAIR_NAME]
security_group = ec2.security_groups[SECURITY_GROUP_ID]


audio_high_params = "-acodec libfaac -ac 2 -ab 128k"
audio_low_params = "-acodec libfaac -ac 2 -ab 64k"
audio_none_params = "-an"

#Once there is more than one re-encode server Creation Time will need to be synchronized across them all
video_general = "-vcodec libx264 -coder 1 -flags +loop -cmp +chroma -partitions +parti8x8+parti4x4+partp8x8+partb8x8 -me_method hex -subq 4 -me_range 16 -g 250 -keyint_min 25 -sc_threshold 40 -i_qfactor 0.71 -b_strategy 1 -qcomp 0.6 -qmin 0 -qmax 69 -qdiff 4 -bf 3 -refs 2 -directpred 1 -trellis 1 -flags2 +bpyramid-mixed_refs+wpred-dct8x8+fastpskip -wpredp 1 -rc_lookahead 20 -threads 16 -async 30 -metadata creation_time=`date --iso-8601=seconds`"
video_30fps = "#{video_general} -r 29.97 -g 59.94 -keyint_min 59.94 -sc_threshold 0"

input = "-threads 16 -i http://#{local_ip}/#{INCOMING_PUB_POINT}.isml/#{INCOMING_PUB_POINT}-#{INCOMING_BITRATE}.m3u8"
output = ""
OUTGOING_PARAMS.each do |bitrate_param|
  output_section = "-f ism \"http://#{local_ip}/#{OUTGOING_PUB_POINT}.isml/Streams(#{bitrate_param.bitrate}k)\""
  encode_section = "#{video_30fps} -b:v #{bitrate_param.bitrate}k -s #{bitrate_param.x_resolution}x#{bitrate_param.y_resolution}"
  if(bitrate_param.audio_type=="high")
    audio_section = audio_high_params
  elsif(bitrate_param.audio_type=="low")
    audio_section = audio_low_params
  else
    audio_section = audio_none_params
  end

  output += audio_section + " " + encode_section + " " + output_section + " "
end

startup_script = <<SCRIPT_END
#!/bin/bash
yum -y update

hostname "Encoder"
echo "*.*          @logs.papertrailapp.com:13780" >> /etc/rsyslog.conf
/etc/init.d/rsyslog restart

echo "Encoder server starting up" | logger -t encode_script

cd /tmp

wget http://s3.amazonaws.com/asccvideodev/ffmpeg
chmod u+x ffmpeg

error_code=99
while [ "$error_code" -gt "0" ] ; do
  echo "Executing ffmpeg" | logger -t encode_script
  echo | ./ffmpeg -y #{input} #{output} 2>&1 | sed 's/\\x0d/\\n/g' | logger -t ffmpeg
  error_code=$?
  echo "ffmpeg result: $error_code" | logger -t encode_script
  sleep 1s
done

echo "Encode complete. Encode server shutting down" | logger -t encode_script
sleep 1s
halt
SCRIPT_END


puts "Creating Amazon Linux instance"
`echo "Creating Amazon Linux instance" | logger -t encode_script`
instance = ec2.instances.create(:image_id => AMAZON_IMAGE_ID, :key_pair => ec2.key_pairs[KEY_PAIR_NAME],
  :security_groups => ec2.security_groups[SECURITY_GROUP_ID], :instance_type => INSTANCE_SIZE,
  :instance_initiated_shutdown_behavior => 'terminate', :user_data => startup_script)

puts "Created. Waiting for instance to start"
while !instance.exists? || instance.status == :pending
  print "."
  $stdout.flush
  sleep 1
end

puts

instance.tag('Name', :value => 'Encode Server')

puts "Instance #{instance.id} launched, status: #{instance.status}"

puts "Public IP:"
puts "#{instance.dns_name}"
`echo "Encode instance created. IP: #{instance.dns_name}" | logger -t encode_script`
