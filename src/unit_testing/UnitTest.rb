
require 'fileutils'

Dir.chdir(File.dirname(__FILE__)) do
	require './TestClass'
	require './../utils/parsing/CliMod'
	require './../utils/output/IoManipulation'
end

module KLib
	
	module UnitTest
		
		BASE_DIR = "KLib_UnitTest"
		
		class TestFramework
			
			attr_reader :test_class
			
			def initialize(test_class)
				@test_class = test_class
			end
			
			def run(logger, inspect_instances)
				ArgumentChecking.type_check(logger, 'logger', Logger)
				ArgumentChecking.type_check(inspect_instances, 'inspect_instances', Boolean)
				
				FileUtils.mkdir_p(File.join(BASE_DIR, @test_class.inspect.gsub('::', '/')))
				
				logger.break
				logger.log(:important, "Starting TestClass: '#{@test_class.inspect}'")
				logger.break(:type => :open)
				legal_methods = @test_class.instance_methods(TestClass)
				logger.log(:debug, "Legal Methods: #{legal_methods.inspect}")
				
				joined_assertions = {}
				
				inst_num = 0
				@test_class.__created_instances.each do |inst|
					inst_num += 1
					logger.break
					FileUtils.mkdir_p(File.join(BASE_DIR, @test_class.inspect.gsub('::', '/'), inst_num.to_s))
					
					logger.log(:print, "Starting 'instance-#{inst_num}'")
					logger.break(:type => :open)
					logger.log(:info, "instance: #{inst.inspect}")if inspect_instances
					logger.break
					
					ran_methods = []
					skipped_methods = []
					
					inst.__method_manager.__methods.each_pair do |method_name, args|
						logger.log(:info, "method: '#{method_name}', args: #{args.inspect}")
						logger.indent + 1
						if legal_methods.include?(method_name)
							if args.nil?
								skipped_methods << method_name
								logger.log(:detailed, "Skipping...")
							else
								ran_methods << method_name
								logger.log(:detailed, "Running...")
								out = nil
								err = nil
								begin
									out, err, raised = IoManipulation.snatch_io(:preserve_raised => true) do
										inst.send(method_name, *args)
									end
									raise raised unless raised.nil?
								rescue Exception => e
									logger.log(:error, e.inspect)
								ensure
									unless out.nil? || out.eof?
										File.open(File.join(BASE_DIR, @test_class.inspect.gsub('::', '/'), inst_num.to_s, "#{method_name}~out.log"), 'w') do |out_file|
											until out.eof?
												out_file.puts(out.readline)
											end
										end
									end
									unless err.nil? || err.eof?
										File.open(File.join(BASE_DIR, @test_class.inspect.gsub('::', '/'), inst_num.to_s, "#{method_name}~err.log"), 'w') do |err_file|
											until err.eof?
												err_file.puts(err.readline)
											end
										end
									end
								end
								
							end
						else
							logger.log(:error, "'#{method_name}' is not a legal method for '#{@test_class}'")
						end
						logger.indent - 1
					end
					
					
					
					unspeced = legal_methods - ran_methods - skipped_methods
					logger.break
					logger.log(:info, "Coverage:")
					logger.indent + 1
					logger.log(:info, "Ran:         (#{ran_methods.length.to_s.rjust(3)}/#{legal_methods.length.to_s.rjust(3)})")
					logger.indent + 1
					ran_methods.each { |met| logger.log(:detailed, "'#{met}'") }
					logger.indent - 1
					logger.log(:info, "Skipped:     (#{skipped_methods.length.to_s.rjust(3)}/#{legal_methods.length.to_s.rjust(3)})")
					logger.indent + 1
					skipped_methods.each { |met| logger.log(:detailed, "'#{met}'") }
					logger.indent - 1
					logger.log(:info, "Unspecified: (#{unspeced.length.to_s.rjust(3)}/#{legal_methods.length.to_s.rjust(3)})")
					logger.indent + 1
					unspeced.each { |met| logger.log(:detailed, "'#{met}'") }
					logger.indent - 1
					logger.indent - 1
					
					logger.break
					logger.log(:detailed, "Assertions:")
					logger.indent + 1
					inst.__assertions.each_pair do |method_name, assertions|
						logger.log(:detailed, "'#{method_name}'")
						logger.indent + 1
						assertions.each { |assert| logger.log(:detailed, assert.to_s) }
						logger.indent - 1
					end
					logger.indent - 1
					
					reports = inst.__assertion_report
					logger.break
					logger.log(:info, "Assertion Reports: #{Assertions::AssertionReport.join(reports.values).inspect}")
					logger.indent + 1
					reports.each_pair { |method_name, report| logger.log(:info, "'#{method_name}' => #{report.inspect}") }
					logger.indent - 1
					
					File.open(File.join(BASE_DIR, @test_class.inspect.gsub('::', '/'), inst_num.to_s, "assertions.log"), 'w') do |assert_file|
						inst.__assertions.each_pair do |method_name, assertions|
							assert_file.puts("#{method_name}:")
							assertions.each { |assert| assert_file.puts("\t#{assert.inspect}") }
							assert_file.puts
						end
					end
					
					if inst.__assertions.values.any? { |val| val.any? { |v| !v.passed } }
						File.open(File.join(BASE_DIR, @test_class.inspect.gsub('::', '/'), inst_num.to_s, "failed_assertions.log"), 'w') do |assert_file|
							inst.__assertions.each_pair do |method_name, assertions|
								fails = assertions.select { |assertion| !assertion.passed }
								if fails.any?
									assert_file.puts("#{method_name}:")
									fails.each { |assert| assert_file.puts("\t#{assert.inspect}") }
									assert_file.puts
								end
							end
						end
					end
					
					joined_assertions.merge!(inst.__assertion_report) { |key, old, new| old.join(new) }
					
					logger.break(:type => :close)
					logger.log(:print, "Finished 'instance-#{inst_num}'")
				end
				full_join = Assertions::AssertionReport.join(joined_assertions.values)
				
				logger.break
				logger.log(:info, "Assertion Reports: #{full_join.inspect}")
				logger.indent + 1
				joined_assertions.each_pair { |method_name, report| logger.log(:info, "'#{method_name}' => #{report.inspect}") }
				logger.indent - 1
				
				logger.break(:type => :close)
				logger.log(:important, "Completed: '#{@test_class.inspect}'")
				
				full_join
			end
			
		end
		
		module FrameworkRunner
			extend CliMod
			
			TESTS_PASSED =   10
			TESTS_FAILED =   11
			TESTS_ERRORED =  12
			
			method_spec(:main) do |spec|
				spec.symbol(:log_level).default_value(:important)
				spec.boolean(:inspect_instances).boolean_data(:mode => :_dont).default_value(false)
			end
			
			def self.main(log_level, inspect_instances, *args)
				FileUtils.rm_rf(BASE_DIR)
				FileUtils.mkdir_p(BASE_DIR)
				#FileUtils.mkdir_p(File.join(BASE_DIR, 'logs'))
				
				logger = KLib::Logger.new(:log_tolerance => log_level)
				logger.add_source(File.new(File.join(BASE_DIR, 'log.log'), 'w'), :target => :out, :range => :always)
				
				puts(Dir.pwd)
				
				logger.break
				logger.log(:always, "Starting TestFramework")
				
				search_strs = args.map { |arg| arg.to_s.gsub(/[\\\/]/, '/') }
				
				logger.break(:type => :open)
				logger.log(:debug, "Search Strings (#{search_strs.length}):")
				logger.indent + 1
				search_strs.each { |str| logger.log(:debug, str) }
				logger.indent - 1
				
				found_files = search_strs.map { |str| Dir.glob(str) }.flatten.select { |f| f.end_with?('.rb') }.map { |f| File.expand_path(f) }
				
				logger.break
				logger.log(:info, "Found (#{found_files.length}) ruby file#{found_files.length == 1 ? '' : 's'}:")
				logger.indent + 1
				found_files.each { |f| logger.log(:detailed, f) }
				logger.indent - 1
				
				found_files.each { |f| require(f) }
				
				logger.break
				logger.log(:info, "Found (#{TestClass.__inherited.length}) UnitTest Class#{TestClass.__inherited.length == 1 ? '' : 'es'}:")
				logger.indent + 1
				TestClass.__inherited.each { |klass| logger.log(:detailed, klass.inspect) }
				logger.indent - 1
				
				reports = {}
				
				framework_classes = TestClass.__inherited.map { |klass| TestFramework.new(klass) }
				framework_classes.each do |framework|
					reports[framework.test_class] = framework.run(logger, inspect_instances)
				end
				
				full_join = Assertions::AssertionReport.join(reports.values)
				logger.break
				logger.log(:print, "AssertionReports: #{full_join.inspect}")
				logger.indent + 1
				reports.each_pair { |test_class, report| logger.log(:print, "'#{test_class}' => #{report.inspect}") }
				logger.indent - 1
				
				if full_join.errors > 0
					result = :errored
				elsif full_join.fails > 0
					result = :failed
				else
					result = :passed
				end
				
				logger.break(:type => :close)
				logger.log(:always, "Complete... Result: #{result.to_s.upcase}")
				
				self.const_get(:"TESTS_#{result.to_s.upcase}")
			end
			
		end
		
	end
	
end

if File.expand_path($0) == File.expand_path(__FILE__)
	result = KLib::UnitTest::FrameworkRunner.parse
	exit(result)
end

