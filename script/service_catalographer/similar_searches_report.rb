#!/usr/bin/env ruby

# Reports on the statistics on similar searches.
#
# Can only take into searches carried out by logged in users
# (as this is the only way of correlating different searches).

require 'pp'

env = "production"

unless ARGV[0].nil? or ARGV[0] == ''
  env = ARGV[0]
end

Rails.env = ActiveSupport::StringInquirer.new(env)

# Load up the Rails app
require File.join(File.dirname(__FILE__), '..', '..', 'config', 'environment')

class SearchTermsTuple
  attr_reader :term1, :term2

  def initialize(term1, term2)
    @term1 = term1
    @term2 = term2
  end

  def hash
    [ @term1.downcase, @term2.downcase ].sort.hash
  end

  def eql?(other)
    (self.term1.downcase == other.term1.downcase && self.term2.downcase == other.term2.downcase) ||
    (self.term1.downcase == other.term2.downcase && self.term2.downcase == other.term1.downcase)
  end
end

activity_logs = ServiceCatalographer::Search::all_possible_activity_logs_for_search([ "culprit_id", "culprit_type", "data" ])

stats = { 
  :users => { },
  :pairs => { } 
}

def add_to_list_case_insensitive(list, value)
  return if list.nil? or value.blank?

  found = false
  
  list.each do |i|
    found = true if i.downcase == value.downcase
  end
  
  list << value unless found
end

def process_activity_logs(logs, stats)
  logs.each do |a|
    query = ServiceCatalographer::Search::search_term_from_hash(a.data)
    if a.culprit_type == "User" && !a.culprit_id.blank? && !query.blank?
      culprit_id = a.culprit_id.to_s
      stats[:users][culprit_id] = [ ] unless stats[:users].has_key?(culprit_id)
      add_to_list_case_insensitive(stats[:users][culprit_id], query)
    end
  end
end

process_activity_logs(activity_logs, stats)

stats[:users].each do |k,v|
  left = 0

  while left < (v.length - 2) do
    for right in (left + 1)...v.length do
      t = SearchTermsTuple.new(v[left], v[right])
      stats[:pairs][t] = 0 unless stats[:pairs].has_key?(t)
      stats[:pairs][t] += 1
    end

    left += 1
  end
end

def report_stats(stats)
  #puts "\n\n#{pp stats}\n\n"

  puts ""
  puts "Similar searches (based on searches carried out by logged in users)"
  puts "==================================================================="
  puts ""
  
  ordered_pairs = [ ]

  stats[:pairs].each do |k,v|
    ordered_pairs << { :tuple => k, :count => v  } 
  end

  ordered_pairs.sort! {|x,y| y[:count] <=> x[:count]}

  ordered_pairs.each do |p|
    puts "#{p[:tuple].term1}  |  #{p[:tuple].term2}  |  (#{p[:count]} times)"
  end
end

puts "Redirecting output of $stdout to log file: '{Rails.root}/log/similar_searches_report_{current_time}.txt' ..."
$stdout = File.new(File.join(File.dirname(__FILE__), '..', '..', 'log', "similar_searches_report_#{Time.now.strftime('%Y%m%d-%H%M')}.txt"), "w")
$stdout.sync = true

report_stats(stats)

# Reset $stdout
$stdout = STDOUT
