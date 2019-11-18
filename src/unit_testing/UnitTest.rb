
require 'fileutils'

require_relative 'TestClass'
require_relative '../utils/parsing/cli/parse_class'
require_relative '../utils/output/IoManipulation'
require_relative '../utils/output/Logger'

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
					
					inst.__method_manager.__methods.each_pair do |method_name, arg_list|
						arg_list.each_with_index do |args, idx|
							logger.log(:info, "method: '#{method_name}', args: #{args.inspect}")
							inst.instance_variable_set(:@__current_args, args)
							logger.indent + 1
							if legal_methods.include?(method_name)
								if args.nil?
									skipped_methods << method_name
									logger.log(:info, "Skipping...")
								else
									ran_methods << method_name
									logger.log(:info, "Running...")
									out = nil
									err = nil
									assertions = inst.__assertions
									assertion_count = assertions.key?(method_name.to_s) ? assertions[method_name.to_s].length : 0
									begin
										out, err, raised = IoManipulation.snatch_io(preserve_raised: true) do
											inst.send(method_name, *args)
										end
										non_passed = assertions[method_name.to_s][assertion_count..-1].select { |assertion| assertion.passed != true }
										logger.log(:info, non_passed.length > 0 ? "failed (#{non_passed.length})" : "passed")
										logger.indent + 1
										non_passed.each { |fail| logger.log(:detailed, fail.inspect) }
										logger.indent - 1
										raise raised unless raised.nil?
									rescue Exception => e
										logger.log(:error, e.inspect)
										logger.indent + 1
										e.backtrace.reverse.each { |bt| logger.log(:debug, bt) }
										logger.indent - 1
									ensure
										unless out.nil? || out.eof?
											File.open(File.join(BASE_DIR, @test_class.inspect.gsub('::', '/'), inst_num.to_s, "#{method_name}-#{idx}~out.log"), 'w') do |out_file|
												out_file.puts(out.readline) until out.eof?
											end
										end
										unless err.nil? || err.eof?
											File.open(File.join(BASE_DIR, @test_class.inspect.gsub('::', '/'), inst_num.to_s, "#{method_name}-#{idx}~err.log"), 'w') do |err_file| 
												err_file.puts(err.readline) until err.eof?
											end
										end
									end
								
								end
							else
								logger.log(:error, "'#{method_name}' is not a legal method for '#{@test_class}'")
							end
							logger.indent - 1
						end
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
			
			TESTS_PASSED =   10
			TESTS_FAILED =   11
			TESTS_ERRORED =  12
			
			cli_spec(extra_argv: true) do |spec|
				spec.symbol(:log_level).default_value(:important).one_of(LogLevelManager::DEFAULT_LOG_LEVELS)
				spec.boolean(:inspect_instances, negative: :dont).default_value(false)
				
				spec.execute do
					show_params
					
					FileUtils.rm_rf(BASE_DIR)
					FileUtils.mkdir_p(BASE_DIR)
					#FileUtils.mkdir_p(File.join(BASE_DIR, 'logs'))
					
					logger = KLib::Logger.new(:log_tolerance => @log_level)
					logger.add_source(File.new(File.join(BASE_DIR, 'log.log'), 'w'), :target => :out, :range => :always)
					
					puts(Dir.pwd)
					
					logger.break
					logger.log(:always, "Starting TestFramework")
					
					search_strs = @argv.map { |arg| arg.to_s.gsub(/[\\\/]/, '/') }
					
					logger.break(:type => :open)
					logger.log(:debug, "Search Strings (#{search_strs.length}):")
					logger.indent + 1
					search_strs.each { |str| logger.log(:debug, str) }
					logger.indent - 1
					
					found_files = search_strs.map { |str| Dir.glob(str.start_with?('@') ? str[1..-1] : str) }.flatten.select { |f| f.end_with?('.rb') }.map { |f| File.expand_path(f) }
					
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
						reports[framework.test_class] = framework.run(logger, @inspect_instances)
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
					
					FrameworkRunner.const_get(:"TESTS_#{result.to_s.upcase}")
				end
			end
			
		end
		
	end
	
end

if File.expand_path($0) == File.expand_path(__FILE__)
	result = KLib::UnitTest::FrameworkRunner.parse
	# exit(result)
	exit
end

