require 'csv'

RANGES = [(0..10), (10..100), (100..1000), (1000..10000), (10000..)].freeze
buckets = Hash.new(0)

CSV.read('movie_dataset.csv', headers: true).each do |row| 
  idx = RANGES.find_index { |range| range.cover?(row['vote_count'].to_i) }
  buckets[idx] += 1
end

buckets.each do |idx, count|
  puts "#{RANGES[idx]}: #{'#' * (count / 20)} - #{count.to_s}"
end
