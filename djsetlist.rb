require 'set'
require 'yaml'
require 'pry'

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

class DjSetlist
  attr_accessor :songs

  def initialize(file)
    @songs = YAML.load(File.read(file))
  end

  def percentage_difference(a, b)
    (a.to_f - b.to_f).abs / ((a + b) / 2.0)
  end

  def similar_bpm(s1, s2)
    percentage_difference(s1[:bpm], s2[:bpm]) <= $bpm_tolerance
  end

  def same_key(s1, s2)
    s1[:key] == s2[:key]
  end

  def adjacent_key(s1, s2)
    $camelot_wheel[s1[:key]].include? s2[:key]
  end

  def compatible_key(s1, s2)
    same_key(s1, s2) or adjacent_key(s1, s2)
  end

  def compatible_songs(song, candidate_songs)
    candidate_songs.select {|s| compatible_key(song, s) and similar_bpm(song, s)}
  end

  def find_longest_chain_from(song, remaining_songs)
    if remaining_songs.empty?
      return [song]
    end
    possibly_next = compatible_songs(song, remaining_songs)
    if possibly_next.empty?
      return [song]
    end
    song_chains = possibly_next.map do |next_song|
      [song] + find_longest_chain_from(next_song, remaining_songs.reject {|s| next_song == s})
    end
    song_chains.max_by(&:length)
  end

  def find_longest_chain
    song_chains = @songs.map do |song|
      find_longest_chain_from(song, @songs.reject {|s| song == s})
    end
    song_chains.max_by(&:length)
  end
end

dj = DjSetlist.new('plasma20_unsorted.yml')
songs = dj.songs
longest = dj.find_longest_chain()
File.open('plasma20_sorted.yml', 'w') {|f| f.write(longest.to_yaml) }