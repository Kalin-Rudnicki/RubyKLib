
files = []
Dir.chdir(File.dirname(__FILE__)) do
   files = Dir.glob('./*/**/*.rb').map { |file| File.expand_path(file) }
end

files.each do |file|
	require(file)
end