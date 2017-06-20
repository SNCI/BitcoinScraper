require 'mechanize'
require 'active_record'
require 'sqlite3'
require 'zip'
require 'csv'

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

url = "http://api.bitcoincharts.com/v1/csv/"
agent = Mechanize.new
agent.pluggable_parser.default = Mechanize::Download

page = agent.get(url)
links = page.links

links.each do |link|
  temp = link.text[/[^.]+/]
  market = temp[0...-3]
  currency = temp[-3..-1]

  agent.get(link).save('tempfile.csv.gz')
  temp = %x[ #{'gunzip -c tempfile.csv.gz'} ]
  sleep(25)
  CSV.parse(temp) do |row|
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
     "#{market}",
     "#{currency}");
     SQL
     db.execute(sql_command)
  end
  File.delete('tempfile.csv.gz')
end
