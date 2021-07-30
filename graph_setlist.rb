require 'set'
require 'yaml'

$bpm_tolerance = 0.1
$camelot_wheel = {
  "G#m": Set.new([:"C#m", :B, :Ebm]),
  "Ebm": Set.new([:"G#m", :Gb, :Bbm]),
  "Bbm": Set.new([:Ebm, :Db, :Fm]),
  "Fm": Set.new([:Bbm, :Ab, :Cm]),
  "Cm": Set.new([:Fm, :Eb, :Gm]),
  "Gm": Set.new([:Cm, :Bb, :Dm]),
  "Dm": Set.new([:Gm, :F, :Am]),
  "Am": Set.new([:Dm, :C, :Em]),
  "Em": Set.new([:Am, :G, :Bm]),
  "Bm": Set.new([:Em, :D, :"F#m"]),
  "F#m": Set.new([:Bm, :A, :"C#m"]),
  "C#m": Set.new([:"F#m", :E, :"G#m"]),
  "B": Set.new([:E, :"G#m", :Gb]),
  "Gb": Set.new([:B, :Ebm, :Db]),
  "Db": Set.new([:Gb, :Bbm, :Ab]),
  "Ab": Set.new([:Db, :Fm, :Eb]),
  "Eb": Set.new([:Ab, :Cm, :Bb]),
  "Bb": Set.new([:Eb, :Gm, :F]),
  "F": Set.new([:Bb, :Dm, :C]),
  "C": Set.new([:F, :Am, :G]),
  "G": Set.new([:C, :Em, :D]),
  "D": Set.new([:G, :Bm, :A]),
  "A": Set.new([:D, :"F#m", :E]),
  "E": Set.new([:A, :"C#m", :B])
}
$camelot_wheel_colors = {
  "G#m": "#56F1DA",
  "Ebm": "#7DF2AA",
  "Bbm": "#AEF589",
  "Fm": "#E8DAA1",
  "Cm": "#FEBFA7",
  "Gm": "#FDAFB7",
  "Dm": "#FDAACC",
  "Am": "#F2ABE4",
  "Em": "#DDB4FD",
  "Bm": "#BECDFD",
  "F#m": "#8EE4F9",
  "C#m": "#55F0F0",
  "B": "#01EDCA",
  "Gb": "#3CEE81",
  "Db": "#86F24F",
  "Ab": "#DFCA73",
  "Eb": "#FFA07C",
  "Bb": "#FF8894",
  "F": "#FF81B4",
  "C": "#EE82D9",
  "G": "#CE8FFF",
  "D": "#9FB6FF",
  "A": "#56D9F9",
  "E": "#00EBEB"
}

# Used for early termination of recursive algorithm
$num_chains = 0
$max_chains = 1000000
$shuffle_seed = 2
$rng = Random.new($shuffle_seed)

# Procs
longest_chain = Proc.new {|songs| songs.max_by(&:length)}

def count_bangers(songs)
  songs.count {|s| s[:banger]}
end

# Get longest chain with the most bangers
most_bangers = Proc.new do |songs|
  songs.max_by do |chain|
    [count_bangers(chain), chain.length]
  end
end

# Get shortest chain with the most bangers
most_bangers_short = Proc.new do |songs|
  songs.max_by do |chain|
    [count_bangers(chain), -1 * chain.length]
  end
end



class DjSetlist
  attr_accessor :songs, :song_graph

  def initialize(file)
    @songs = YAML.load(File.read(file))
    @song_graph = create_graph()
  end

  def puts_song_graph
    @song_graph.each do |song, neighbors|
      puts song[:title]
      puts "  => #{neighbors.map {|n| n[:title]}.join('; ')}"
    end
  end

  def format_as_graphviz
    def format_song_attrs(song)
      fillcolor = $camelot_wheel_colors[song[:key].to_sym].dump
      width = song[:bpm] * 0.02
      "  #{song[:title].dump} [fillcolor=#{fillcolor},width=#{width}];"
    end

    def format_song_edges(song, neighbors)
      "  #{song[:title].dump} -- { #{neighbors.map {|n| n[:title].dump}.join(' ')} };"
    end

    nodes = @songs.map {|song| format_song_attrs(song)}
    edges = @song_graph.map {|song, neighbors| format_song_edges(song, neighbors)}
    node_styles = "  node [style=filled,shape=circle,fixedsize=true]"
    "strict graph {\n#{node_styles}\n#{nodes.join("\n")}\n#{edges.join("\n")}\n}"
  end

  def percentage_difference(a, b)
    (a.to_f - b.to_f).abs / ((a + b) / 2.0)
  end

  # If doubling is true, also check if the bpm is similar
  # when the lower of the two bpms is doubled
  def similar_bpm(s1, s2, doubling=true)
    with_original = percentage_difference(s1[:bpm], s2[:bpm]) <= $bpm_tolerance
    return true if with_original
    if doubling
      if s1[:bpm] < s2[:bpm]
        with_doubled = percentage_difference(2 * s1[:bpm], s2[:bpm]) <= $bpm_tolerance
      else
        with_doubled = percentage_difference(s1[:bpm], 2 * s2[:bpm]) <= $bpm_tolerance
      end
      return with_original || with_doubled
    end
    false
  end

  def same_key(s1, s2)
    s1[:key].to_sym == s2[:key].to_sym
  end

  def adjacent_key(s1, s2)
    $camelot_wheel[s1[:key].to_sym].include? s2[:key].to_sym
  end

  def compatible_key(s1, s2)
    same_key(s1, s2) or adjacent_key(s1, s2)
  end

  def compatible_songs(song, candidate_songs)
    candidate_songs.select {|s| compatible_key(song, s) and similar_bpm(song, s)}
  end

  def create_graph
    song_graph = {}
    @songs.each do |song|
      other_songs = @songs.reject {|s| song == s}
      song_graph[song] = compatible_songs(song, other_songs)
    end
    song_graph
  end

  def find_longest_chain_from(song, used_songs, max_func)
    if $num_chains >= $max_chains
      return []
    end
    if used_songs.include? song
      $num_chains += 1
      return []
    end
    song_neighbors = @song_graph[song]
    song_neighbors.shuffle!(random: $rng)
    if song_neighbors.empty?
      return [song]
    end
    song_chains = song_neighbors.map do |next_song|
      [song] + find_longest_chain_from(next_song, used_songs + [song], max_func)
    end
    max_func.call(song_chains)
  end

  def find_longest_chain(max_func)
    song_chains = @songs.map do |song|
      find_longest_chain_from(song, [], max_func)
    end
    max_func.call(song_chains)
  end

  def random_longest_chain(trials, max_func)
    longest_chain = []
    trials.times do |trial|
      puts("Trial #{trial}")
      $num_chains = 0
      @songs.shuffle!(random: $rng)
      @song_graph = create_graph()
      chain = find_longest_chain(max_func)
      longest_chain = chain if chain.length > longest_chain.length
      puts("Best # of Bangers: #{count_bangers(longest_chain)}")
      puts("Best Length: #{longest_chain.length}")
    end
    longest_chain
  end
end

# For automatically generating the longest playlist
dj = DjSetlist.new('input/hull2021hype_full.yml')
trials = 10
longest = dj.random_longest_chain(trials, most_bangers_short)
File.open("output/hull2021_trials_#{trials}_random_#{$shuffle_seed}.yml", 'w') {|f| f.write(longest.to_yaml) }

# For visualizing the songs in a graph
# dj = DjSetlist.new('input/hull2021hype_full.yml')
# File.open("output/hull2021hype_full.dot", 'w') {|f| f.write(dj.format_as_graphviz)}