require 'mechanize'
require 'csv'

def get_agent

  mechanize = Mechanize.new
  mechanize.follow_meta_refresh = true 
  mechanize.verify_mode = OpenSSL::SSL::VERIFY_NONE
  mechanize.pluggable_parser.default = Mechanize::Download 
  mechanize.set_proxy(nil,nil)
  return mechanize

end

def form_price_tables page

  prices , quantities = [] , []
  rows = page.search("#product-dollars tr").count
  for i in 1..rows-1
    quantities.push(page.search("#product-dollars tr")[i].search("td")[0].text.gsub(",","").to_i)
    prices.push(page.search("#product-dollars tr")[i].search("td")[1].text.to_f)
  end
  return prices , quantities

end

def get_required_price prices , quantities , quantity

  price = 0.00
  for i in 0..prices.count-1
    if quantities[i]>quantity && price==0
      price = prices[i-1]
    end 
  end
  price = price==0 ? prices.last : price
  return price

end

def scrape_digikey part_numbers , mf

  agent = get_agent()
  details , key = [["PART #","QUANTITY","MOQ","STOCK","PRICE","LINK"]] , 1
  part_numbers.each do |part_number|
    flag = 0
    search_page = agent.get("http://www.digikey.com/product-search/en?keywords=#{part_number[0]}")
    rows = search_page.search("#productTable tr").count 
    for i in 1..rows-1
      search_res = search_page.search("#productTable tr")[i]
      s = search_res.search("td")[4]
      moq = search_res.search("td")[9].text.strip.to_i 
      if s.text.strip == part_number[0] && moq == 1 
        product_page_link = "http://www.digikey.com"+s.search("a")[0]["href"]
        product_page = agent.get(product_page_link)
        quantity = product_page.search("#quantityAvailable").text.strip.gsub("\r","").gsub("\n","").split(" ")[0].gsub(",","").to_i
        prices , quantities = form_price_tables(product_page)
        price = get_required_price(prices,quantities,part_number[1].to_i)
        # Convert USD to INR with freights & profit costs
        price = price * mf 
        puts "\nFOUND MATCH : #{part_number} , #{product_page_link} , MOQ #{moq} , STOCK #{quantity} , PRICE #{price}"
        if flag == 0
          details[key] = [part_number[0],part_number[1],moq,quantity,price,product_page_link]
        else 
          details[key] = ["","",moq,quantity,price,product_page_link]
        end
        key = key+1
        flag = flag+1
      end
    end  
  end
  return details
end

def read_csv filename

  dir = Dir.pwd
  Dir.chdir("../auto-sourcing-csv-files/input")
  part_numbers = CSV.read(filename)
  puts "\nCompleted reading the part numbers from csv file - #{filename}."
  Dir.chdir(dir)
  return part_numbers

end

def output_csv details , filename

  dir = Dir.pwd
  unless Dir.exist? "../auto-sourcing-csv-files/output"
    Dir.mkdir("../auto-sourcing-csv-files/output")
  end
  Dir.chdir("../auto-sourcing-csv-files/output")
  csv_str = details.inject([]) { |csv, row|  csv << CSV.generate_line(row) }.join("")
  File.open(filename, "w") {|f| f.write(details.inject([]) { |csv, row|  csv << CSV.generate_line(row) }.join(""))}
  puts "\nCompleted sourcing for the part numbers. Output csv file - #{filename}. Output directory - auto-sourcing-csv-files/output."
  puts "\n"
  Dir.chdir(dir)

end

def get_user_input

  dir = Dir.pwd
  Dir.chdir("../auto-sourcing-csv-files/input")
  files = Dir.entries(".")
  files.delete(".")
  files.delete("..")
  puts "\nLIST OF INPUT EXCEL FILES - "
  for i in 0..files.count-1
    puts "(#{i+1}) #{files[i]}"
  end
  puts "\nEnter your selected choice (1 - #{files.count}) : "
  choice = gets.chomp.to_i
  if !(choice >= 1 && choice <= files.count)
    puts "\nInvalid selection of choice. Choose choice between 1 & #{files.count}."   
    Dir.chdir(dir)
    file = get_user_input()
    return file
  else
    Dir.chdir(dir)
    return files[choice-1] 
  end
end  

def get_factor

  mf = 0.0
	puts "\nEnter your required multiplication factor for prices (USD to INR) : "
	mf = gets.chomp.to_f  
	return mf

end

input_file = get_user_input()
puts "\nChosen input file : #{input_file}"
output_file = "digikey_output_"+input_file
part_numbers = read_csv(input_file)
mf = get_factor()
details = scrape_digikey(part_numbers,mf)
output_csv(details,output_file)
