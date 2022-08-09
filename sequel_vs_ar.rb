require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'
  gem 'pg'
  gem 'ruby-prof-flamegraph'
  gem 'sequel'
  gem 'activerecord', '~> 6.1.6'
end

require 'benchmark'
require 'pg'
require 'sequel'
require 'active_record'
require 'date'

AMOUNT_TO_MEASURE = 1000 #_000

postgres_sequel = Sequel.connect(ENV['POSTGRES_URL'])
postgres_activerecord = ActiveRecord::Base.establish_connection(ENV['POSTGRES_URL'])

class SequelProductRepository
  def initialize(database)
    @database = database
    @products = database[:sequel_products]
  end

  def prepare
    database.drop_table?(:sequel_products)
    database.create_table(:sequel_products) do
      primary_key :id
      String :name, unique: true, null: false
      Float :price, null: false
      DateTime :created_at, null: false
    end
  end

  def insert(amount)
    amount.times { |index| products.insert(name: "product ##{index}", price: index * 100, created_at: DateTime.now) }
  end

  def read(amount)
    amount.times do |index|
      products.limit(index + 1).to_a
    end
  end

  private

  attr_accessor :database, :products
end

class Product < ActiveRecord::Base
  self.table_name = :ar_products
end

class ArProductRepository
  def initialize(_database)
  end

  def prepare
    ActiveRecord::Schema.define do
      self.verbose = false

      create_table(:ar_products, force: true) do |t|
        t.string   :name
        t.float    :price
        t.datetime :created_at
      end
    end
  end

  def insert(amount)
    amount.times do |index|
      Product.create(name: "product ##{index}", price: index * 100, created_at: DateTime.now)
    end
  end

  def read(amount)
    amount.times do |index|
      Product.limit(index + 1).to_a
    end
  end

  private

  attr_accessor :database, :products
end

repos = [
  SequelProductRepository.new(postgres_sequel),
  ArProductRepository.new(postgres_activerecord),
]
repos.each(&:prepare)

Benchmark.bm(20) do |bm|
  bm.report('Postgres Sequel write') { repos[0].insert(AMOUNT_TO_MEASURE) }
  bm.report('Postgres Sequel read') { repos[0].read(AMOUNT_TO_MEASURE) }
  bm.report('Postgres AR write') { repos[1].insert(AMOUNT_TO_MEASURE) }
  bm.report('Postgres AR read') { repos[1].read(AMOUNT_TO_MEASURE) }
end

# Flamegraphs
GC.start
repos.each(&:prepare)
profiles = {}
profiles[:sequel_write] = RubyProf.profile { repos[0].insert(AMOUNT_TO_MEASURE) }
profiles[:sequel_read] = RubyProf.profile { repos[0].read(AMOUNT_TO_MEASURE) }
profiles[:ar_write] = RubyProf.profile { repos[1].insert(AMOUNT_TO_MEASURE) }
profiles[:ar_read] = RubyProf.profile { repos[1].read(AMOUNT_TO_MEASURE) }

# Print a graph profile to text
profiles.each do |name, prof|
  RubyProf::FlameGraphPrinter.new(prof).print(File.open("flamegraph_#{name}", 'w+'), {})
end
