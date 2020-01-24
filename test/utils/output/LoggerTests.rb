
require_relative '../../../src/utils/output/Logger'

$klib_logger.set_log_tolerance(:detailed)
$klib_logger.add_rule(:"rule_1-rule_1.1")

class Klass
	
	klib_logger
	
	def initialize
		debug("DEBUG")
		print("PRINT", rule: :rule_1)
		
	end
	
end

Klass.new
