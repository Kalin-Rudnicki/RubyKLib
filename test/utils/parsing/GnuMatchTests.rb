
Dir.chdir(File.dirname(__FILE__)) do
	require './../../../src/utils/parsing/GnuMatch'
end

def test(string, *options)
	puts("attempting to match '#{string}' to #{options.inspect}")
	puts("\tsingle: #{KLib::GnuMatch.match(string, options).inspect}")
	puts("\tmulti:  #{KLib::GnuMatch.multi_match(string, options).inspect}")
	puts
end

%w{kal opt opti opt_p k_r}.each { |str| test(str, *%w{kalin kalin_rudnicki option_parser opts kalin_other}) }
