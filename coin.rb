require 'mechanize'
require 'nokogiri'
require 'sqlite3'
require 'zip'
require 'csv'
require 'pry'

database = File.new("db.db", "a")
database.close
db = SQLite3::Database.new("db.db")


sql_command = <<-SQL
CREATE TABLE IF NOT EXISTS bitcoin(
  unixtime string NOT NULL,
  price string NOT NULL,
  amount string NOT NULL,
  market string NOT NULL,
  currency string NOT NULL);
SQL
db.execute(sql_command)

url = "index.html"
agent = Mechanize.new
agent.pluggable_parser.default = Mechanize::Download
page = File.open(url) { |f| Nokogiri::HTML(f) }
temp = page.css('a')
links = []
temp.each do |l|
  out = {}
  out[:url] = "https://api.bitcoincharts.com/v1/csv/" + "#{l.inner_text}"
  temp = l.inner_text[/[^.]+/]
  out[:market] = temp[0...-3]
  out[:currency] = temp[-3..-1]
  if out[:currency] != nil && out[:market] != ""
   links << out
 end
end

links.each do |link|
  agent.get(link[:url]).save('tempfile.csv.gz')
  sleep 5
  %x[  #{'gzcat tempfile.csv.gz >tempfile.csv'} ]
  CSV.foreach("tempfile.csv") do |row|
      sql_command = <<-SQL
      INSERT INTO bitcoin(
       unixtime,
       price,
       amount,
       market,
       currency
     )
      VALUES
       (
       "#{row[0]}",
       "#{row[1]}",
       "#{row[2]}",
       "#{link[:market]}",
       "#{link[:currency]}");
       SQL
       db.execute(sql_command)
    end
 File.delete('tempfile.csv.gz')
 File.delete('tempfile.csv')
end
