require 'net/http'
require 'fileutils'
require 'json'
require 'open-uri'

def make_request uri
  req = Net::HTTP::Get.new(uri)
  req['Accept'] = 'application/json'
  req['Accept-Charset'] = 'utf-8'
  req['Keep-Alive'] = 'true'
  req['Cookie'] = '_simpleauth_sess=' + AUTH_TOKEN + ';'

  res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
    http.request(req)
  end

  if res.code != '200' 
    puts res.body
    puts res.code
    raise "Problem getting orders"
  end

  res
end

def get_order order_key
  raise "Order Key can not be blank!" if order_key.nil? || order_key == ''
  order_uri = URI("https://www.humblebundle.com/api/v1/order/#{order_key}?ajax=true'")

  res = make_request order_uri  

  JSON.parse(res.body)
end

def get_orders
  orders_uri = URI('https://www.humblebundle.com/api/v1/user/order?ajax=true')
  
  res = make_request orders_uri

  JSON.parse(res.body).collect{|o| o["gamekey"]}
end

def find_correct_download subproduct
  download = subproduct['downloads'].first
  
  download_struct = download['download_struct'].select{|ds| ds['name'].downcase == DEFAULT_FILE_TYPE.downcase if ds["name"]}.first
  download_struct ||= download['download_struct'].select{|ds| ds['name'].downcase == BACKUP_FILE_TYPE.downcase if ds["name"]}.first
  download_struct
end

AUTH_TOKEN = '"<ENTER YOUR TOKEN>"'
DOWNLOAD_FOLDER = './download'
DOWNLOAD_LIMIT = 10
DEFAULT_FILE_TYPE =  'EPUB'
BACKUP_FILE_TYPE = 'PDF'

#Make sure DOWNLOAD_FOLDER
FileUtils::mkdir_p DOWNLOAD_FOLDER

orders = get_orders
puts "I found #{orders.length} orders!"

all_qualified_subproducts = orders.collect do |order|
  full_order =  get_order order
  subproducts  = full_order['subproducts']
  subproducts.select do |subproduct|
    subproduct['downloads'].length > 0
  end
end.flatten

all_qualified_subproducts.each do |subproduct|
  download_struct = find_correct_download subproduct
  
  unless download_struct
    puts "Unable to find valid file for: #{subproduct['human_name']}"
    next
  end

  filename = "#{DOWNLOAD_FOLDER}/#{subproduct['human_name'].gsub(/[^a-zA-z0-9 ]/,'').gsub(' ', '-').downcase}.#{download_struct['name'].downcase}" 

  if File.file?(filename)
    puts "Skipping #{filename} because it already exisits "
    next
  end
  
  puts "Downloading: #{filename}"

  open(filename, 'wb') do |file|
    file << open(download_struct['url']['web']).read
  end
end


