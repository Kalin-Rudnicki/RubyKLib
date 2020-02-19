
builds_dir = File.expand_path(File.join(__FILE__, "../builds"))

reg = /(\d+)\.(\d+)\.(\d+)\.gem$/
files = Dir.glob("#{builds_dir}/*.gem").map do |f|
  [f, reg.match(f)[1..3].map { |v| v.to_i }]
end

newest = files.max do |a, b|
  major = a[1][0] <=> b[1][0]
  if major != 0
    major
  else
    minor = a[1][1] <=> b[1][1]
    if minor != 0
      minor
    else
      a[1][2] <=> b[1][2]
    end
  end
end[0]

system("gem", "install", newest)
