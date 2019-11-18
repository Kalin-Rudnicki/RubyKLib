require_relative '../src/utils/parsing/cli/parse_class'
require 'fileutils'

module KLibBuild
	
	cli_spec do |spec|
		spec.symbol(:type).default_value(:minor).one_of(:major, :minor, :patch, :overwrite)
		spec.flag(:cleanup, default: true, negative: :skip)
		spec.flag(:install, default: false, negative: :dont)
		
		spec.execute do
			show_params
			
			Dir.chdir(File.dirname(__FILE__)) do
				# Find omits
				omit = File.read('blacklist.txt').split("\n")
				
				# Find new version
				builds = Dir.glob('builds/*').map do |file|
					mat = /^klib-(\d+)\.(\d+)\.(\d+)\.gem$/.match(file.split(/[\\\/]/)[-1])
					(1..3).map { |i| mat[i].to_i }
				end
				if builds.empty?
					prev_version = ''
					version = '0.1.0'
				else
					newest = builds.max do |a, b|
						tmp = a[0] <=> b[0]
						if tmp == 0
							tmp = a[1] <=> b[1]
							if tmp == 0
								a[2] <=> b[2]
							else
								tmp
							end
						else
							tmp
						end
					end
					prev_version = newest.join('.')
					case @type
						when :major
							version = "#{newest[0] + 1}.1.0"
						when :minor
							version = "#{newest[0]}.#{newest[1] + 1}.0"
						when :patch
							version = "#{newest[0]}.#{newest[1]}.#{newest[2] + 1}"
						when :overwrite
							version = newest.join('.')
						else
							raise "What is going on?"
					end
				end
				
				puts("=====| version |=====")
				puts("version type: #{@type}")
				puts("prev-version: #{prev_version}")
				puts(" new-version: #{version}")
				puts
				
				# Build
				puts("=====| build |=====")
				FileUtils.cp_r('../src', 'files/lib/klib') 
				omit.each { |o| FileUtils.rm_rf(File.join('files/lib/klib', o)) }
				File.open('files/lib/klib/version.rb', 'w') { |file| file.write("module KLib\nVERSION = #{version.inspect}\nend") }
				FileUtils.cp('../README.md', 'files/README.md')
				FileUtils.cp('files/klib.rb', 'files/lib/klib/klib.rb')
				
				Dir.chdir('files') { system('gem build klib.gemspec') }
				
				FileUtils.mv("files/klib-#{version}.gem", "builds/klib-#{version}.gem")
				puts
				
				# Cleanup
				puts("=====| cleanup |=====")
				if @cleanup
					FileUtils.rm_rf('files/lib/klib')
					FileUtils.rm_rf('files/README.md')
				else
					puts("skipping cleanup")
				end
				puts
				
				# Install
				puts("=====| install |=====")
				if @install
					system("gem install builds/klib-#{version}.gem")
				else
					puts("skipping install")
				end
			end
		end
	end
	
end

KLibBuild.parse
