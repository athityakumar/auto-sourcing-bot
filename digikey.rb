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

def scrape_digikey part_numbers
  agent = get_agent()
  details , key = [["PART #","QUANTITY","MOQ","STOCK","PRICE","LINK"]] , 1
  # part_numbers = [["SN74HC74N",50],["LM324N",1400]]

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
        price = price * 120 
        puts "FOUND MATCH : #{part_number} , #{product_page_link} , MOQ #{moq} , STOCK #{quantity} , PRICE #{price}"
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

  part_numbers = CSV.read(filename)
  puts part_numbers
  return part_numbers

end

def output_csv details , filename

  csv_str = details.inject([]) { |csv, row|  csv << CSV.generate_line(row) }.join("")
  File.open(filename, "w") {|f| f.write(details.inject([]) { |csv, row|  csv << CSV.generate_line(row) }.join(""))}

end

part_numbers = read_csv("sample_input.csv")
details = scrape_digikey(part_numbers)
output_csv(details,"sample_output_digikey.csv")