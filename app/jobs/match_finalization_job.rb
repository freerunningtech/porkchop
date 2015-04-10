require 'matchmaker'

class MatchFinalizationJob < ActiveJob::Base
  queue_as :default

  def perform(match)
    @match = match
    send_notification!
    adjust_elo!
    collect_achievements!
    matchmake!
  end

  private

  attr_reader :match

  def send_notification!
    SlackNotification.new(match).deliver
  end

  def adjust_elo!
    EloAdjustment.new(
      victor: match.victor,
      loser: match.loser
    ).adjust!
  end

  def collect_achievements!
    [match.home_player, match.away_player].each do |player|
      player.all_achievements.select(&:earned?).each(&:adjust_rank!)
    end
  end

  def matchmake!
    home_player, away_player = Matchmaker.choose
    return unless home_player && away_player

    Match.create!(
      home_player: home_player,
      away_player: away_player
    )
  end
end
