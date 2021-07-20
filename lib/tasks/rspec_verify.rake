task "rspec:verify" do
  require "json"
  require "set"

  # Compare a full rspec report and a collection of partial rspec reports to make
  # sure they cover the same set of examples. This script should be runnable
  # without being on Buildkite.
  #
  # If run locally, output some hints to help folks run a comparison.

  puts "Comparing the full rspec suite against the pieces which were run."
  puts

  full_path = "tmp/rspec.json"

  unless File.exists? full_path
    puts "Full report is missing."
    puts
    puts "Generate one with:"
    puts
    puts "  bin/rspec --dry-run --format json --out #{full_path}"
    puts

    exit 2
  end

  full = JSON.parse(File.read(full_path))
  full_examples = full.fetch("examples").map { |example| example.fetch("id") }.to_set
  puts "#{full_examples.size} examples in the full suite"

  pieces_paths = Dir["tmp/rspec-*.json"]

  unless pieces_paths.any?
    puts "Pieces are misssing."
    puts
    puts "Find a buildkite build:"
    puts
    puts "  https://buildkite.com/sj26/knapsack-test/builds/last?state=finished"
    puts
    puts "then download its pieces with with:"
    puts
    puts %{  bk artifact download --build BUILD-UUID "tmp/rspec-*.json"}
    puts

    exit 2
  end

  pieces = pieces_paths.each_with_object({}) do |path, hash|
    hash[path[%r{tmp/rspec-(.*?)\.json}, 1]] = JSON.parse(File.read(path))
  end
  pieces_examples = pieces.transform_values { |piece| piece.fetch("examples").map { |example| example.fetch("id") }.to_set }
  all_pieces_examples = pieces_examples.values.sum(Set.new)
  puts "#{all_pieces_examples.size} examples across all pieces"

  if full_examples == all_pieces_examples
    puts
    puts "Examples match! ☑️"
  else
    puts
    puts "Examples do not match."

    only_in_full = full_examples - all_pieces_examples
    if only_in_full.any?
      puts
      puts "Only in full suite:"
      only_in_full.each do |example|
        puts "- #{example}"
      end
    end

    pieces_examples.each do |piece_name, piece_examples|
      only_in_piece = piece_examples - full_examples
      if only_in_piece.any?
        puts

        # Can we link to the job by its uuid?
        if ENV["BUILDKITE"] && ENV["BUILDKITE_BUILD_URL"] && piece_name =~ /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/i
          link_name = piece_name
          link_url = "#{ENV["BUILDKITE_BUILD_URL"]}\##{piece_name}"
          link = "\e]1339;url=#{link_url.gsub(";", "%3b")}#{";content=#{link_name.gsub(";", "%3b")}"}\a"

          puts "Only in #{link}:"
        else
          puts "Only in #{piece_name}:"
        end

        only_in_piece.each do |example|
          puts "- #{example}"
        end
      end
    end

    puts
    puts "We're not running the whole suite of specs, so we cannot ship this code confidently to production. Something might be wrong in knapsack or rspec configuration."

    exit 1
  end
end
