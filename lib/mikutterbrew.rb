#!/usr/bin/env ruby
# encoding: utf-8

require "digest"
require "json"
require "net/http"
require "optparse"
require "rubygems"
require "shellwords"
require "tmpdir"
require "uri"

require "resona"

class Mikutter
  def current_version
    current = `mikutter --version`.split
    current[1]
  end

  def latest_version
    query_api if @latest_version.nil?
    @latest_version
  end

  def release_uri
    query_api if @release_uri.nil?
    @release_uri
  end

  def up_to_date?
    curr = Gem::Version.new(current_version)
    lat = Gem::Version.new(latest_version)

    curr >= lat
  end

  def download(target=nil)
    uri = URI(release_uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == "https")

    response = http.get(uri.request_uri)
    response.value unless response.is_a? Net::HTTPSuccess

    basename = File.basename(uri.path)
    target = basename if target.nil?
    target = File.join(target, basename) if File.directory? target
    open(target, "wb") { |f| f.write(response.body) }

    target
  end

  def stage
    raise ArgumentError, "Block is required" unless block_given?
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        tarball = download
        unpack(tarball)
        digest = Digest::SHA256.file(tarball).hexdigest
        Dir.chdir("mikutter") { yield digest }
      end
    end
  end

  private

  def query_api
    api_uri = URI("http://mikutter.hachune.net/download.json")
    args = { query: "unstable", count: 1 }
    api_uri.query = URI.encode_www_form(args)

    http = Net::HTTP.new(api_uri.host, api_uri.port)
    http.use_ssl = (api_uri.scheme == "https")

    response = http.get(api_uri.request_uri)
    response.value unless response.is_a? Net::HTTPSuccess

    latest_release = JSON.load(response.body).first
    @latest_version = latest_release["version_string"]
    @release_uri = latest_release["url"]
  end

  def unpack(file)
    system("tar", "xzf", Shellwords.shellescape(file))
  end
end


class Formula
  attr_reader :path, :content

  def initialize(pth=nil)
    @path = pth || "#{`brew --repo homebrew/core`.chomp}/Formula/mikutter.rb"
    @content = File.read(@path)
  end

  def replace_url!(new_url)
    old = /^( +)url ".*"\n/
    new = "\\1url \"#{new_url}\"\n"
    @content.gsub!(old, new)
  end

  def replace_checksum!(new_checksum)
    old = /^( +)sha256 ".*"\n/
    new = "\\1sha256 \"#{new_checksum}\"\n"
    @content.gsub!(old, new)
  end

  def replace_resource_stanzas!(new_stanzas)
    resource_stanzas =
      /(?:( *)resource +\".*\" +do\n(?:.*\n)*?\1end\n*)+/

    indent = resource_stanzas.match(@content)[1]
    return if indent.nil?
    new_stanzas.gsub!(/^(?!$)/, indent)

    @content.gsub!(resource_stanzas, "#{new_stanzas}\n")
  end
end


if __FILE__ == $0
  if ARGV.length > 1
    $stderr.puts "Error: Wrong number of arguments."
    $stderr.puts "Usage: #{$PROGRAM_NAME} [formula_path]"
    exit false
  end

  mikutter = Mikutter.new
  if mikutter.up_to_date?
    puts "mikutter is up to date."
    exit
  end

  checksum = ""
  resource_stanzas = ""
  mikutter.stage do |sha|
    checksum = sha
    resource_stanzas = Resona.generate_resource_stanzas("Gemfile")
  end

  formula_path = if ARGV.length == 1
                   ARGV[0]
                 else
                   nil
                 end
  formula = Formula.new(formula_path)
  formula.replace_url!(mikutter.release_uri)
  formula.replace_checksum!(checksum)
  formula.replace_resource_stanzas!(resource_stanzas)

  puts formula.content
end
