command = 'find . -type f \( -name "*.s" -o -name "*.inc" -o -name "*.mac" \)'
output = `#{command}`
files = output.split.delete_if { |elm| elm.start_with?("./com", "./listing", "./cc") }.map { |elm| elm[2..-1] }
puts files

