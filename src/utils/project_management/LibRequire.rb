
Dir.chdir(File.dirname(__FILE__)) do
	require './../validation/HashNormalizer'
end

module Kernel
	
	alias :pre_lib_require :require
	def require(*args)
		hash_args = KLib::HashNormalizer.normalize!(KLib::HashNormalizer.hash_args_strip!(args), :allowed_casing => :snake, :allowed_types => :sym) do |norm|
			norm.check_lib.default_value(true).type_check(TrueClass, FalseClass)
		end
		begin
			pre_lib_require(*args)
		rescue LoadError => e_1
			begin
				return lib_require(*args) if hash_args[:check_lib]
			rescue KLib::LibRequire::LibRequireError => e_2
				# Feels sketchy putting the re-raise here, even though it should technically be the same exact behavior
			end
			raise e_1
		end
	end
	
end

module KLib
	
	module LibRequire
		
		$stderr.puts("No 'RUBY_LibRequire' Environment-Variable set. Set it (similar to the PATH variable) to make this warning go away. Set to NULL for no paths.") unless ENV.key?('RUBY_LibRequire')
		PATH = ENV.key?('RUBY_LibRequire') && ENV['RUBY_LibRequire'] != 'NULL' ? ENV['RUBY_LibRequire'].split(File::PATH_SEPARATOR).map { |p| p.gsub(/[\/\\]/, '/') } : []
		PATH.each_with_index do |path, idx|
			$stderr.puts("ENV['RUBY_LibRequire'][#{idx}] = '#{path}'. Path does not exist...") unless File.exist?(path)
		end
		
		class LibRequireError < RuntimeError
			
			attr_reader :searched_paths, :file_name
			
			def initialize(file_name, searched_paths)
				@file_name = file_name
				@searched_paths = searched_paths
				super("Unable to find '#{file_name}' in any of #{PATH.inspect}.")
			end
			
		end
		
		def self.lib_require(file_name)
			ArgumentChecking.type_check(file_name, 'file_name', String)
			file_name += '.rb' if File.extname(file_name).length == 0
			searched_paths = []
			PATH.each do |path|
				expanded = File.expand_path(file_name, path)
				searched_paths << expanded
				if File.exist?(expanded)
					return pre_lib_require(expanded)
				end
			end
			raise LibRequireError.new(file_name, searched_paths)
		end
		
	end
	
end

def lib_require(*args)
	KLib::LibRequire.lib_require(*args)
end
