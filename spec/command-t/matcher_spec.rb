# Copyright 2010-present Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

require 'spec_helper'
require 'ostruct'
require 'command-t/ext' # CommandT::Matcher

describe CommandT::Matcher do
  def matcher(*paths)
    scanner = OpenStruct.new(:paths => paths)
    CommandT::Matcher.new(scanner)
  end

  describe 'initialization' do
    it 'raises an ArgumentError if passed nil' do
      expect { CommandT::Matcher.new(nil) }.to raise_error(ArgumentError)
    end
  end

  describe '#sorted_matches_for' do
    def ordered_matches(paths, query)
      matcher(*paths).sorted_matches_for(query, :recurse => true)
    end

    it 'raises an ArgumentError if passed nil' do
      expect { matcher.sorted_matches_for(nil) }.to raise_error(ArgumentError)
    end

    it 'returns empty array when source array empty' do
      expect(matcher.sorted_matches_for('foo')).to eq([])
      expect(matcher.sorted_matches_for('')).to eq([])
    end

    it 'returns empty array when no matches' do
      matcher = matcher(*%w[foo/bar foo/baz bing])
      expect(matcher.sorted_matches_for('xyz')).to eq([])
    end

    it 'returns matching paths' do
      matcher = matcher(*%w[foo/bar foo/baz bing])
      matches = matcher.sorted_matches_for('z')
      expect(matches.map { |m| m.to_s }).to eq(['foo/baz'])
      matches = matcher.sorted_matches_for('bg')
      expect(matches.map { |m| m.to_s }).to eq(['bing'])
    end

    it 'performs case-insensitive matching' do
      matches = matcher('Foo').sorted_matches_for('f')
      expect(matches.map { |m| m.to_s }).to eq(['Foo'])
    end

    it 'considers the space character to match a literal space' do
      paths = ['path_no_space', 'path with/space']
      matches = matcher(*paths).sorted_matches_for('path space')
      expect(matches.map { |m| m.to_s }).to eq(['path with/space'])
    end

    context 'when the ignore_spaces option in specified' do
      it 'ignores the space character' do
        paths = ['path_no_space', 'path with/space']
        matches = matcher(*paths).sorted_matches_for('path space', :ignore_spaces => true)
        expect(matches.map { |m| m.to_s }).to eq(['path_no_space', 'path with/space'])
      end
    end

    it 'considers the empty string to match everything' do
      matches = matcher('foo').sorted_matches_for('')
      expect(matches.map { |m| m.to_s }).to eq(['foo'])
    end

    it 'does not consider mere substrings of the query string to be a match' do
      expect(matcher('foo').sorted_matches_for('foo...')).to eq([])
    end

    it 'prioritizes shorter paths over longer ones' do
      expect(ordered_matches(%w[
        articles_controller_spec.rb
        article.rb
      ], 'art')).to eq(%w[
        article.rb
        articles_controller_spec.rb
      ])
    end

    it 'prioritizes matches after "/"' do
      expect(ordered_matches(%w[fooobar foo/bar], 'b')).to eq(%w[foo/bar fooobar])

      # note that / beats _
      expect(ordered_matches(%w[foo_bar foo/bar], 'b')).to eq(%w[foo/bar foo_bar])

      # / also beats -
      expect(ordered_matches(%w[foo-bar foo/bar], 'b')).to eq(%w[foo/bar foo-bar])

      # and numbers
      expect(ordered_matches(%w[foo9bar foo/bar], 'b')).to eq(%w[foo/bar foo9bar])

      # and periods
      expect(ordered_matches(%w[foo.bar foo/bar], 'b')).to eq(%w[foo/bar foo.bar])

      # and spaces
      expect(ordered_matches(['foo bar', 'foo/bar'], 'b')).to eq(['foo/bar', 'foo bar'])
    end

    it 'prioritizes matches after "-"' do
      expect(ordered_matches(%w[fooobar foo-bar], 'b')).to eq(%w[foo-bar fooobar])

      # - also beats .
      expect(ordered_matches(%w[foo.bar foo-bar], 'b')).to eq(%w[foo-bar foo.bar])
    end

    it 'prioritizes matches after "_"' do
      expect(ordered_matches(%w[fooobar foo_bar], 'b')).to eq(%w[foo_bar fooobar])

      # _ also beats .
      expect(ordered_matches(%w[foo.bar foo_bar], 'b')).to eq(%w[foo_bar foo.bar])
    end

    it 'prioritizes matches after " "' do
      expect(ordered_matches(['fooobar', 'foo bar'], 'b')).to eq(['foo bar', 'fooobar'])

      # " " also beats .
      expect(ordered_matches(['foo.bar', 'foo bar'], 'b')).to eq(['foo bar', 'foo.bar'])
    end

    it 'prioritizes matches after numbers' do
      expect(ordered_matches(%w[fooobar foo9bar], 'b')).to eq(%w[foo9bar fooobar])

      # numbers also beat .
      expect(ordered_matches(%w[foo.bar foo9bar], 'b')).to eq(%w[foo9bar foo.bar])
    end

    it 'prioritizes matches after periods' do
      expect(ordered_matches(%w[fooobar foo.bar], 'b')).to eq(%w[foo.bar fooobar])
    end

    it 'prioritizes matching capitals following lowercase' do
      expect(ordered_matches(%w[foobar fooBar], 'b')).to eq(%w[fooBar foobar])
    end

    it 'prioritizes matches earlier in the string' do
      expect(ordered_matches(%w[******b* **b*****], 'b')).to eq(%w[**b***** ******b*])
    end

    it 'prioritizes matches closer to previous matches' do
      expect(ordered_matches(%w[**b***c* **bc****], 'bc')).to eq(%w[**bc**** **b***c*])
    end

    it 'scores alternative matches of same path differently' do
      # ie:
      # app/controllers/articles_controller.rb
      expect(ordered_matches(%w[
        a**/****r******/**t*c***_*on*******.**
        ***/***********/art*****_con*******.**
      ], 'artcon')).to eq(%w[
        ***/***********/art*****_con*******.**
        a**/****r******/**t*c***_*on*******.**
      ])
    end

    it 'provides intuitive results for "artcon" and "articles_controller"' do
      expect(ordered_matches(%w[
        app/controllers/heartbeat_controller.rb
        app/controllers/articles_controller.rb
      ], 'artcon')).to eq(%w[
        app/controllers/articles_controller.rb
        app/controllers/heartbeat_controller.rb
      ])
    end

    it 'provides intuitive results for "aca" and "a/c/articles_controller"' do
      expect(ordered_matches(%w[
        app/controllers/heartbeat_controller.rb
        app/controllers/articles_controller.rb
      ], 'aca')).to eq(%w[
        app/controllers/articles_controller.rb
        app/controllers/heartbeat_controller.rb
      ])
    end

    it 'provides intuitive results for "d" and "doc/command-t.txt"' do
      expect(ordered_matches(%w[
        TODO
        doc/command-t.txt
      ], 'd')).to eq(%w[
        doc/command-t.txt
        TODO
      ])
    end

    it 'provides intuitive results for "do" and "doc/command-t.txt"' do
      expect(ordered_matches(%w[
        TODO
        doc/command-t.txt
      ], 'do')).to eq(%w[
        doc/command-t.txt
        TODO
      ])
    end

    it "doesn't incorrectly accept repeats of the last-matched character" do
      # https://github.com/wincent/Command-T/issues/82
      matcher = matcher(*%w[ash/system/user/config.h])
      expect(matcher.sorted_matches_for('usercc')).to eq([])

      # simpler test case
      matcher = matcher(*%w[foobar])
      expect(matcher.sorted_matches_for('fooooo')).to eq([])

      # minimal repro
      matcher = matcher(*%w[ab])
      expect(matcher.sorted_matches_for('aa')).to eq([])
    end

    it 'ignores dotfiles by default' do
      matcher = matcher(*%w[.foo .bar])
      expect(matcher.sorted_matches_for('foo')).to eq([])
    end

    it 'shows dotfiles if the query starts with a dot' do
      matcher = matcher(*%w[.foo .bar])
      expect(matcher.sorted_matches_for('.fo')).to eq(%w[.foo])
    end

    it "doesn't show dotfiles if the query contains a non-leading dot" do
      matcher = matcher(*%w[.foo.txt .bar.txt])
      expect(matcher.sorted_matches_for('f.t')).to eq([])

      # counter-example
      expect(matcher.sorted_matches_for('.f.t')).to eq(%w[.foo.txt])
    end
  end
end
