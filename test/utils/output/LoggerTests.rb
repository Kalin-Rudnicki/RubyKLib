
Dir.chdir(File.dirname(__FILE__)) do
	require './../../../src/utils/output/Logger'
end

logger = KLib::Logger.new(:log_tolerance => :always, :display_time => false)
logger.set_log_tolerance(:print, :rule => :cuz)

logger.print("Hello")
logger.debug("Hello 2.0", rule: :cuz)
logger.print("Hello 2.1", rule: :cuz)
