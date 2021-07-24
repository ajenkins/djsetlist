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

# Used for early termination of recursive algorithm
$num_chains = 0
$max_chains = 1000000
$shuffle_seed = 2
$rng = Random.new($shuffle_seed)

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

  def find_longest_chain_from(song, used_songs)
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
      [song] + find_longest_chain_from(next_song, used_songs + [song])
    end
    song_chains.max_by(&:length)
  end

  def find_longest_chain
    song_chains = @songs.map do |song|
      find_longest_chain_from(song, [])
    end
    song_chains.max_by(&:length)
  end

  def random_longest_chain(trials)
    longest_chain = []
    trials.times do |trial|
      puts("Trial #{trial}")
      $num_chains = 0
      @songs.shuffle!(random: $rng)
      @song_graph = create_graph()
      chain = find_longest_chain()
      longest_chain = chain if chain.length > longest_chain.length
      puts("Longest chain: #{longest_chain.length}")
    end
    longest_chain
  end
end

dj = DjSetlist.new('input/hull2021hype_full.yml')
trials = 50
longest = dj.random_longest_chain(trials)
File.open("output/hull2021_trials_#{trials}_random_#{$shuffle_seed}.yml", 'w') {|f| f.write(longest.to_yaml) }