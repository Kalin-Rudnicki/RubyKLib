
Dir.chdir(File.dirname(__FILE__)) do
	require './../../../src/utils/output/Logger'
end

logger = KLib::Logging::Logger.new(:log_tolerance => :never, :display_time => false)
logger.set_log_tolerance(:print, :rule => :cuz)

logger.valid_levels.each { |level| logger.log(level, "Logging at: '#{level}'", :rule => :cuz) }
