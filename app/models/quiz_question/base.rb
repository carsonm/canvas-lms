#
# Copyright (C) 2012 Instructure, Inc.
#
# This file is part of Canvas.
#
# Canvas is free software: you can redistribute it and/or modify it under
# the terms of the GNU Affero General Public License as published by the Free
# Software Foundation, version 3 of the License.
#
# Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
# details.
#
# You should have received a copy of the GNU Affero General Public License along
# with this program. If not, see <http://www.gnu.org/licenses/>.
#

class QuizQuestion::Base
  # typically you'll call this factory method rather than instantiating a subclass directly
  def self.from_question_data(data)
    type_name = data[:question_type]
    klass = question_types[type_name]
    klass ||= QuizQuestion::UnknownQuestion
    klass.new(data)
  end

  @@question_types = {}
  mattr_reader :question_types

  def self.inherited(klass)
    type_name = klass.question_type
    raise("question type #{type_name} already exists") if question_types.key?(type_name)
    question_types[type_name] = klass
  end

  # override to change the name of the question type, defaults to the underscore-ized class name
  def self.question_type
    self.name.demodulize.underscore
  end

  def initialize(question_data)
    # currently all the attributes are synthesized from @question_data
    # since questions are stored in this format anyway, it prevents us from
    # having to do a bunch of translation to some other format
    @question_data = question_data
  end

  def question_id
    @question_data[:id]
  end

  def points_possible
    @question_data[:points_possible].to_f
  end

  def incorrect_dock
    @question_data[:incorrect_dock].try(:to_f)
  end

  #
  # Scoring Methods to override in the subclass
  #

  # the total number of parts to a question
  # many questions have just one part (fill in the blank, etc)
  # some questions have many parts and the score is (correct / total) * points_possible
  # text-only questions have no parts
  def total_answer_parts
    1
  end

  # where the scoring of the question happens
  #
  # a UserAnswer is passed in, and the # of parts correct in the answer is returned
  #
  # for questions types with just one answer part, return 1 for correct and 0 for incorrect
  # for questions types with multiple answer parts, return the total # of parts that are correct
  #
  # you can also return true for full credit, or false for no credit
  #
  # if no answer is given at all, return nil
  #
  # (note this means nil != false in this return value)
  def correct_answer_parts(user_answer)
    nil
  end

  # Return the number of explicitly incorrect answer parts
  #
  # This will never be called before correct_answer_parts is called, so it can
  # be calculated there if that's easier.
  #
  # If this is > 0, the user will be docked for each answer part that they got
  # incorrect. Most question types leave this at 0, so the user isn't punished
  # extra for wrong answers.
  def incorrect_answer_parts(user_answer)
    0
  end

  # override and return true if the answer can't be auto-scored
  def requires_manual_scoring?(user_answer)
    false
  end

  def score_question(answer_data)
    user_answer = QuizQuestion::UserAnswer.new(self.question_id, self.points_possible, answer_data)
    user_answer.total_parts = total_answer_parts
    correct_parts = correct_answer_parts(user_answer)

    if !correct_parts.nil?
      correct_parts = 0 if correct_parts == false
      correct_parts = user_answer.total_parts if correct_parts == true

      user_answer.incorrect_parts = incorrect_answer_parts(user_answer)
      correct_parts = 0 if (correct_parts - user_answer.incorrect_parts) < user_answer.total_parts && @question_data[:allow_partial_credit] == false

      user_answer.correct_parts = correct_parts
      user_answer.incorrect_dock = incorrect_dock if user_answer.incorrect_parts > 0
    elsif user_answer.undefined_if_blank? || requires_manual_scoring?(user_answer)
      user_answer.undefined = true
    end

    user_answer
  end
end

Dir[Rails.root + "app/models/quiz_question/*_question.rb"].each { |f| require_dependency f }
