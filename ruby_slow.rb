require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'
  gem 'pg'
  gem 'ruby-prof-flamegraph'
  gem 'sequel'
  gem 'sqlite3'
end

require 'benchmark'
require 'pg'
require 'sequel'
require 'date'

AMOUNT_TO_MEASURE = 1_000_000

class ArrayDatabase
  def initialize(database: [])
    @database = database
  end

  def drop_table?(_table_name)
    @database = []
  end

  def create_table(_table_name, &block)
    @database = []
  end

  def [](_table_name)
    self
  end

  def insert(attributes)
    @database << attributes
  end

  def count
    @database.length
  end

  def avg(attribute_name)
    @database.inject(0.0) { |sum, record| sum + record[attribute_name] } / @database.size
  end

  def limit(amount)
    self.class.new(database: @database.first(amount))
  end

  def all
    @database
  end
end

array = ArrayDatabase.new
sqlite = Sequel.sqlite
postgres = Sequel.connect(ENV['POSTGRES_URL'])

class ProductRepository
  def initialize(database)
    @database = database
    @products = database[:products]
  end

  def prepare
    database.drop_table?(:products)
    database.create_table(:products) do
      primary_key :id
      String :name, unique: true, null: false
      Float :price, null: false # Yea, I know!
      DateTime :created_at, null: false
    end
  end

  def insert(amount)
    amount.times { |index| products.insert(name: "product ##{index}", price: index * 100, created_at: DateTime.now) }
  end

  def read(amount)
    amount.times { |index| products.limit(10).all.to_a }
  end

  def count
    products.count
  end

  def average
    products.avg(:price)
  end

  private

  attr_accessor :database, :products
end

databases = [array, sqlite, postgres]
repos = databases.map do |db|
  repo = ProductRepository.new(db)
  repo.prepare
  repo
end

Benchmark.bm(20) do |bm|
  bm.report('Mem write') { repos[0].insert(AMOUNT_TO_MEASURE) }
  bm.report('Sqlite mem write') { repos[1].insert(AMOUNT_TO_MEASURE) }
  bm.report('Postgres write') { repos[2].insert(AMOUNT_TO_MEASURE) }

  bm.report('Mem read') { repos[0].read(AMOUNT_TO_MEASURE) }
  bm.report('Sqlite mem read') { repos[1].read(AMOUNT_TO_MEASURE) }
  bm.report('Postgres read') { repos[2].read(AMOUNT_TO_MEASURE) }

  bm.report('Mem count') { repos[0].count }
  bm.report('Sqlite mem count') { repos[1].count }
  bm.report('Postgres count') { repos[2].count }

  bm.report('Mem avg') { repos[0].average }
  bm.report('Sqlite mem avg') { repos[1].average }
  bm.report('Postgres avg') { repos[2].average }
end

# Check that all databases work as expected
# print out the average price
repos.each { |repo| puts "The average price is: #{repo.average}" }


# Flamegraphs
GC.start
repos[0].prepare
repos[2].prepare
profiles = {}
# profiles[:mem_write] = RubyProf.profile { repos[0].insert(AMOUNT_TO_MEASURE) }
# profiles[:mem_read] = RubyProf.profile { repos[0].read(AMOUNT_TO_MEASURE) }
# profiles[:pg_write] = RubyProf.profile { repos[2].insert(AMOUNT_TO_MEASURE) }
# profiles[:pg_read] = RubyProf.profile { repos[2].read(AMOUNT_TO_MEASURE) }

profiles[:all] = RubyProf.profile {
  repos[0].insert(AMOUNT_TO_MEASURE)
  repos[0].read(AMOUNT_TO_MEASURE)
  repos[2].insert(AMOUNT_TO_MEASURE)
  repos[2].read(AMOUNT_TO_MEASURE)
}


# Print a graph profile to text
profiles.each do |name, prof|
  RubyProf::FlameGraphPrinter.new(prof).print(File.open("flamegraph_#{name}", 'w+'), {})
end
