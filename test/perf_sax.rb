#!/usr/bin/env ruby -wW1

$: << '.'
$: << '..'
$: << '../lib'
$: << '../ext'

if __FILE__ == $0
  while (i = ARGV.index('-I'))
    x,path = ARGV.slice!(i, 2)
    $: << path
  end
end

require 'optparse'
require 'ox'
require 'sample'
require 'files'
begin
  require 'nokogiri'
rescue Exception => e
end
begin
  require 'libxml'
rescue Exception => e
end

$verbose = 0
$ox_only = false
$all_cbs = false
$filename = nil # nil indicates new file names perf.xml will be created and used
$filesize = 1000 # KBytes
$iter = 100

opts = OptionParser.new
opts.on("-v", "increase verbosity")                            { $verbose += 1 }
opts.on("-x", "ox only")                                       { $ox_only = true }
opts.on("-a", "all callbacks")                                 { $all_cbs = true }
opts.on("-f", "--file [String]", String, "filename")           { |f| $filename = f }
opts.on("-i", "--iterations [Int]", Integer, "iterations")     { |i| $iter = i }
opts.on("-s", "--size [Int]", Integer, "file size in KBytes")  { |s| $filesize = s }
opts.on("-h", "--help", "Show this display")                   { puts opts; Process.exit!(0) }
rest = opts.parse(ARGV)

$xml_str = nil
$ox_time = 0
$no_time = 0
$lx_time = 0

# size is in Kbytes
def create_file(filename, size)
  head = %{<?xml version="1.0"?>
<?ox version="1.0" mode="object" circular="no" xsd_date="no"?>
<!DOCTYPE table PUBLIC "-//ox//DTD TABLE 1.0//EN" "http://www.ohler.com/DTDs/TestTable-1.0.dtd">
<table>
}
  tail = %{</table>
}
  row = %{  <!-- row %08d element -->
  <row id="%08d">
    <cell id="A" type="Fixnum">1234</cell>
    <cell id="B" type="String">A string.</cell>
    <cell id="C" type="String">This is a longer string that stretches over a larger number of characters.</cell>
    <cell id="D" type="Float">-12.345</cell>
    <cell id="E" type="Date">2011-09-18 23:07:26 +0900</cell>
    <cell id="F" type="Image"><![CDATA[xx00xx00xx00xx00xx00xx00xx00xx00xx00xx00xx00xx00xx00xx00xx00xx00xx00xx00xx00]]></cell>
  </row>
}
  cnt = (size * 1000 - head.size - tail.size) / row.size
  File.open(filename, "w") do |f|
    f.write(head)
    cnt.times do |i|
      f.write(row % [i,i])
    end
    f.write(tail)
  end
end

class OxSax < ::Ox::Sax
  def start_element(name, attrs);  end
  def error(message, line, column); puts message; end
end

class OxAllSax < OxSax
  def end_element(name);  end
  def instruct(target, attrs); end
  def doctype(value); end
  def comment(value); end
  def cdata(value); end
  def text(value); end
end

unless defined?(::Nokogiri).nil?
  class NoSax < Nokogiri::XML::SAX::Document
    def start_element(name, attrs = []); end
    def error(message); puts message; end
    def warning(message); puts message; end
  end
  class NoAllSax < NoSax
    def characters(text); end
    def cdata_block(string); end
    def comment(string); end
    def end_document(); end
    def end_element(name); end
    def start_document(); end
    def xmldecl(version, encoding, standalone); end
  end
end

unless defined?(::LibXML).nil?
  class LxSax
    include LibXML::XML::SaxParser::Callbacks
    def on_start_element(element, attributes); end
  end
  class LxAllSax < LxSax
    def on_cdata_block(cdata); end
    def on_characters(chars); end
    def on_comment(msg); end
    def on_end_document(); end
    def on_end_element(element); end
    def on_end_element_ns(name, prefix, uri); end
    def on_error(msg); end
    def on_external_subset(name, external_id, system_id); end
    def on_has_external_subset(); end
    def on_has_internal_subset(); end
    def on_internal_subset(name, external_id, system_id); end
    def on_is_standalone(); end
    def on_processing_instruction(target, data); end
    def on_reference(name); end
    def on_start_document(); end
    def on_start_element_ns(name, attributes, prefix, uri, namespaces); end
  end
end

def perf_stringio()
  start = Time.now
  handler = $all_cbs ? OxAllSax.new() : OxSax.new()
  $iter.times do
    input = StringIO.new($xml_str)
    Ox.sax_parse(handler, input)
    input.close
  end
  $ox_time = Time.now - start
  puts "StringIO SAX parsing #{$iter} times with Ox took #{$ox_time} seconds."

  return if $ox_only

  unless defined?(::Nokogiri).nil?
    handler = Nokogiri::XML::SAX::Parser.new($all_cbs ? NoAllSax.new() : NoSax.new())
    start = Time.now
    $iter.times do
      input = StringIO.new($xml_str)
      handler.parse(input)
      input.close
    end
    $no_time = Time.now - start
    puts "StringIO SAX parsing #{$iter} times with Nokogiri took #{$no_time} seconds."
  end

  unless defined?(::LibXML).nil?
    start = Time.now
    $iter.times do
      input = StringIO.new($xml_str)
      parser = LibXML::XML::SaxParser.io(input)
      parser.callbacks = $all_cbs ? LxAllSax.new() : LxSax.new()
      parser.parse
      input.close
    end
    $lx_time = Time.now - start
    puts "StringIO SAX parsing #{$iter} times with LibXML took #{$lx_time} seconds."
  end

  puts "\n"
  puts ">>> Ox is %0.1f faster than Nokogiri SAX parsing using StringIO." % [$no_time/$ox_time] unless defined?(::Nokogiri).nil?
  puts ">>> Ox is %0.1f faster than LibXML SAX parsing using StringIO." % [$lx_time/$ox_time] unless defined?(::LibXML).nil?
  puts "\n"
end

def perf_fileio()
  puts "\n"
  puts "A #{$filesize} KByte XML file was parsed #{$iter} for this test."
  puts "\n"
  start = Time.now
  handler = $all_cbs ? OxAllSax.new() : OxSax.new()
  $iter.times do
    input = IO.open(IO.sysopen($filename))
    Ox.sax_parse(handler, input)
    input.close
  end
  $ox_time = Time.now - start
  puts "File IO SAX parsing #{$iter} times with Ox took #{$ox_time} seconds."

  return if $ox_only

  unless defined?(::Nokogiri).nil?
    handler = Nokogiri::XML::SAX::Parser.new($all_cbs ? NoAllSax.new() : NoSax.new())
    start = Time.now
    $iter.times do
      input = IO.open(IO.sysopen($filename))
      handler.parse(input)
      input.close
    end
    $no_time = Time.now - start
    puts "File IO SAX parsing #{$iter} times with Nokogiri took #{$no_time} seconds."
  end

  unless defined?(::LibXML).nil?
    start = Time.now
    $iter.times do
      input = IO.open(IO.sysopen($filename))
      parser = LibXML::XML::SaxParser.io(input)
      parser.callbacks = $all_cbs ? LxAllSax.new() : LxSax.new()
      parser.parse
      input.close
    end
    $lx_time = Time.now - start
    puts "File IO SAX parsing #{$iter} times with LibXML took #{$lx_time} seconds."
  end

  puts "\n"
  puts ">>> Ox is %0.1f faster than Nokogiri SAX parsing using file IO." % [$no_time/$ox_time] unless defined?(::Nokogiri).nil?
  puts ">>> Ox is %0.1f faster than LibXML SAX parsing using file IO." % [$lx_time/$ox_time] unless defined?(::LibXML).nil?
  puts "\n"
end

if $filename.nil?
  create_file('perf.xml', $filesize)
  $filename = 'perf.xml'
end
$xml_str = File.read($filename)

# perf_stringio()
perf_fileio()
