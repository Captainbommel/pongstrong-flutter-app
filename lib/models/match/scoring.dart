// Scoring utilities for beer pong match results.
//
// Provides functions to calculate points, determine match winners,
// and validate score combinations.

/// Calculates the points awarded to each team based on match scores.
///
/// Returns `(team1Points, team2Points)` or `null` if the scores are invalid.
///
/// Point distribution by outcome:
/// - Normal win (10-x): 3/0
/// - Overtime win (16/19): 2/1
/// - Deathcup: 4/0
/// - Deathcup overtime: 3/1
(int, int)? calculatePoints(int score1, int score2) {
  if (!isValid(score1, score2)) {
    return null;
  }

  const winner = [3, 2, 4, 3];
  const looser = [0, 1, 0, 1];

  // deathcup
  if (score1 == -1) {
    return (winner[2], looser[2]);
  } else if (score2 == -1) {
    return (looser[2], winner[2]);
  }
  // deathcup overtime
  if (score1 == -2) {
    return (winner[3], looser[3]);
  } else if (score2 == -2) {
    return (looser[3], winner[3]);
  }
  // normal
  if (score1 == 10 && score2 < 10) {
    return (winner[0], looser[0]);
  } else if (score2 == 10 && score1 < 10) {
    return (looser[0], winner[0]);
  }
  // overtime
  if ((score1 == 16 || score1 == 19) && score1 > score2) {
    return (winner[1], looser[1]);
  } else if ((score2 == 16 || score2 == 19) && score2 > score1) {
    return (looser[1], winner[1]);
  }
  // 1 on 1
  if (score2 >= 19 && score1 > score2) {
    return (winner[1], looser[1]);
  } else if (score1 >= 19 && score2 > score1) {
    return (looser[1], winner[1]);
  }

  return null;
}

/// Determines which team won based on the scores.
///
/// Returns `1` for team 1, `2` for team 2, or `null` for a tie / invalid scores.
int? determineWinner(int score1, int score2) {
  if (!isValid(score1, score2)) {
    return null;
  }

  // deathcup
  if (score1 < 0) {
    return 1;
  } else if (score2 < 0) {
    return 2;
  }
  // normal
  if (score1 > score2) {
    return 1;
  } else if (score2 > score1) {
    return 2;
  }

  return null;
}

/// Validates whether a pair of scores represents a legal match result.
///
/// Accepts normal wins (10-x), overtime (16/19), deathcup (-1/-2),
/// and open-ended 1-on-1 results (both ≥ 19, one strictly higher).
bool isValid(int b1, int b2) {
  if (b1 == -1 && b2 >= 0 && b2 <= 10) return true;
  if (b2 == -1 && b1 >= 0 && b1 <= 10) return true;

  if (b1 == -2 && b2 >= 0 && b2 >= 10) return true;
  if (b2 == -2 && b1 >= 0 && b1 >= 10) return true;

  if (b1 == 10 && b2 >= 0 && b2 < 10) return true;
  if (b2 == 10 && b1 >= 0 && b1 < 10) return true;

  if (b1 == 16 && b2 >= 10 && b2 < 16) return true;
  if (b2 == 16 && b1 >= 10 && b1 < 16) return true;

  if (b1 == 19 && b2 >= 16 && b2 < 19) return true;
  if (b2 == 19 && b1 >= 16 && b1 < 19) return true;

  // 1 on 1: both ≥ 19, one strictly higher
  if (b1 >= 19 && b2 >= 19 && b1 != b2) return true;

  return false;
}
