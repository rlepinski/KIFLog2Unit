#!/usr/bin/env ruby

require 'FileUtils'
require 'optparse'
require 'nokogiri'

class Testcase
	attr :name, true
	attr :time, true
	attr :description, true
	attr :status, true
	attr :message, true
	attr :error, true
	attr :failures, true

	re1='((?:2|1)\\d{3}(?:-|\\/)(?:(?:0[1-9])|(?:1[0-2]))(?:-|\\/)(?:(?:0[1-9])|(?:[1-2][0-9])|(?:3[0-1]))(?:T|\\s)(?:(?:[0-1][0-9])|(?:2[0-3])):(?:[0-5][0-9]):(?:[0-5][0-9]))'	# Time Stamp 1
	re2='([+-]?\\d*\\.\\d+)(?![-+0-9\\.])'	# Float 1
	re3='(\\s+)'	# White Space 1
	re4='((?:[^\[]+))'	# Word 1
	re5='(\\[.*?\\])'	# Square Braces 1
	re6='(\\s+)'	# White Space 2
	re=(re1+re2+re3+re4+re5+re6)

	LINE_STRIP_REGEX=Regexp.new(re,Regexp::IGNORECASE)

	def initialize
    	@status = "PASS"
    	@error = ""
    	@failures = 0
  	end

  	def self.readLine(log)
  		begin
	  		line = log.readline.strip
			line.slice! line.scan(LINE_STRIP_REGEX).join("") if line =~ LINE_STRIP_REGEX
			return line
		rescue 
			return nil
		end
	end

  	def self.parseNextTestScenario(log)
  		testcase = Testcase.new
  		divider_counter = 0

  		while divider_counter < 4 do
  			line = readLine(log)

  			break unless line

			if line.end_with?("-----------") 
				divider_counter = divider_counter + 1
				next
			end

			# get the testcase description
			testcase.description = log.readline.strip if divider_counter == 1

			if divider_counter == 2
				# Look for failures
				if line.start_with?("FAIL ")
					testcase.status = "FAIL"
					testcase.message = line.scan(/(: )([^\n]*)$/)[0][1]
					testcase.failures += 1
				end

				# if we've failed, make sure we have the whole message and/or error
				if testcase.status == "FAIL"
					# if the line doesn't start with either PASS or FAIL, there was probably a newline in either the error or message
					if not line.start_with?("FAIL ") and not line.start_with?("PASS")
						if line.start_with?("FAILING ERROR")
							testcase.error = line.scan(/(: )([^\n]*)$/)[0][1]
						# if we haven't assigned an error yet, this is more of the message
						elsif testcase.error.empty?
							testcase.message << "\n #{line}"
						# if we've assigned an error and we have a broken line, it's part of the error
						else
							testcase.error << "\n #{line}"
						end
					end
				end
			end

			# Get the total time from the summary
			testcase.time = line.scan(/[\d\.]+/)[0].to_f if divider_counter == 3
		end

		testcase
	end

  	def self.fromLog(input_file)
  		log = File.open(input_file)

		#Find the start of the actual log by searching for the BEGIN KIF TEST RUN message
		first_line = readLine(log)
		until first_line =~ /BEGIN KIF TEST RUN/ do
				first_line = readLine(log)
		end

		n_scenarios = first_line.scan(/[\d]+/)[0].to_i;

		tests = Array.new
		1.upto(n_scenarios) do
			tests << parseNextTestScenario(log)
		end

		tests
	end
end


test_suite_name = nil
input_file = nil
output_dir = nil

optparse = OptionParser.new do|opts|
	opts.banner = "Usage: KIFLog2JUnit.rb -n test_suite_name -f input_file -o output_directory"

	opts.on('-n', '--name test_suite_name', 'Test suite name') do |test_name|
		test_suite_name = test_name
	end

	opts.on('-f', '--file input_file', 'File to parse') do |input|
		input_file = input
	end

	opts.on('-o', '--output output_dirECTORY', 'Output directory') do |output|
		output_dir = output
	end

	
  opts.on( '-h', '--help', 'Display this screen' ) do
    puts opts
    exit
  end
end

optparse.parse!

# Handle quick options
if (!input_file && !test_suite_name && (ARGV.count == 2 || ARGV.count == 3)) 
	test_suite_name = ARGV[0]
	input_file = ARGV[1]
	output_dir = ARGV[2]
end

# Verify we have required input file
abort("Fatal Error - Input file is required") unless input_file
raise ArgumentError unless File.exists?(input_file)

# Need a valid test name
abort("No test suite name provided") unless test_suite_name

if output_dir == nil
	output_dir = Dir.pwd + "/test-reports"
	FileUtils.mkpath output_dir unless File.exists? output_dir
end

test_cases = Testcase.fromLog(input_file)
file_timestamp = File.mtime(input_file)

failures = test_cases.inject(0) { |sum, item| sum + item.failures}

xml_builder = Nokogiri::XML::Builder.new(:encoding => "UTF-8") do |xml|
	xml.testsuite(:errors => "0", :failures => failures, :hostname => "mobilemini.local", :name => test_suite_name, :tests => test_cases.count, :timestamp => file_timestamp){
		test_cases.each do |test_case|
			xml.testcase(:classname => test_suite_name, :name => test_case.description, :time => test_case.time){
				xml.failure test_case.error, :message => test_case.message, :type => "Failure" if test_case.status.eql?("FAIL")
			}
		end
	}
end

output_filename = output_dir + "/"+ File.basename(File.expand_path(input_file), '.*') + ".xml"
output = File.open(output_filename, 'w')
output.write(xml_builder.to_xml)
output.close






