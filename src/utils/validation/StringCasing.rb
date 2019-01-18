
Dir.chdir(File.dirname(__FILE__)) do
	require './../validation/HashNormalizer'
end

module StringCasing
	
	REGEX = {
		:snake => {
			false => /^([a-z]*)(_[a-z]*)*$/,
			true => /^([a-z]+)(_([a-z]+|\d+))*$/
		}.freeze,
		:camel => {
			:either => {
				false => /^([A-Za-z][a-z]*)([A-Z][a-z]*)*$/,
				true => /^([A-Za-z][a-z]*)([A-Z][a-z]*|\d+)*$/
			}.freeze,
			:upcase => {
				false => /^([A-Z][a-z]*)+$/,
				true => /^([A-Z][a-z]*)([A-Z][a-z]*|\d+)*$/
			}.freeze,
			:downcase => {
				false => /^([a-z]+)([A-Z][a-z]*)*$/,
				true => /^([a-z]+)([A-Z][a-z]*|\d+)*$/
			}.freeze
		}.freeze
	}.freeze
	
	def self.matches?(string, type, hash_args = {})
		KLib::ArgumentChecking.type_check(string, 'string', String)
		KLib::ArgumentChecking.enum_check(type, 'type', :snake, :camel)
		hash_args = KLib::HashNormalizer.normalize(hash_args) do |norm|
			norm.behavior.default_value(:error).enum_check(:error, :boolean)
			
			norm.allow_numerics(:nums).type_check(Boolean)
			norm.camel_start_case(:camel_start).no_default.enum_check(:either, :upcase, :downcase)
		end
		raise "You can not set 'camel'" if type == :snake && hash_args.key?(:camel_start_case)
		hash_args[:camel_start_case] ||= :either
		
		regex = (type == :snake ? REGEX[:snake][hash_args[:allow_numerics]] : REGEX[:camel][hash_args[:camel_start_case]][hash_args[:allow_numerics]])
		passes = regex.match?(string)
		return true if passes
		case hash_args[:behavior]
			when :error
				raise StringCaseMatchError.new(string, regex)
			when :boolean
				return false
			else
				raise 'what is happening...'
		end
	end
	
	class StringCaseMatchError < RuntimeError
		attr_reader :string, :regex
		def initialize(string, regex)
			@string = string
			@regex = regex
			super("Could not match string '#{string}' to regex #{regex.inspect}")
		end
	end

end
