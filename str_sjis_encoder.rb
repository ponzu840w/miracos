require 'nkf'
require 'optparse'

def convert_to_shift_jis(string)
  NKF.nkf('-sxm0', string).bytes.map { |byte| format('$%02X', byte) }.join(', ')
end

def convert_ca65_japanese_to_shift_jis(input_filename, output_filename)
  File.open(input_filename, 'r:utf-8') do |input|
    File.open(output_filename, 'w:utf-8') do |output|
      input.each_line do |line|
        # ダブルクォーテーションで囲まれた部分のみ抽出
        quoted_parts = line.scan(/"(.*?)"/)
        new_line = line.dup
        quoted_parts.each do |match|
          content = match[0]
          if content =~ /[^\x00-\x7F]/
            shift_jis_string = convert_to_shift_jis(content)
            new_line.sub!("\"#{content}\"", "\"#{shift_jis_string}\"")
          end
        end
        output.puts new_line
      end
    end
  end
end

# コマンドライン引数の解析
options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: ruby script.rb [options]"

  opts.on("-i", "--input INPUT", "Input file name") do |input|
    options[:input] = input
  end

  opts.on("-o", "--output OUTPUT", "Output file name") do |output|
    options[:output] = output
  end
end.parse!

# 入力ファイルと出力ファイルが指定されているか確認
if options[:input] && options[:output]
  convert_ca65_japanese_to_shift_jis(options[:input], options[:output])
else
  puts "Please specify both input and output file names."
  puts "Usage: ruby script.rb -i input.asm -o output.asm"
end
