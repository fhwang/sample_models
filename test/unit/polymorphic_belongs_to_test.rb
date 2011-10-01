require File.dirname(__FILE__) + "/../test_helper"

class PolymorphicBelongsToTest < SampleModelsTestCase
  def test_fills_association_with_anything_from_another_class
    bookmark = Bookmark.sample
    assert_not_nil bookmark.bookmarkable
    assert_equal ActiveRecord::Base, bookmark.bookmarkable.class.superclass
    assert_not_equal Bookmark, bookmark.bookmarkable.class
  end
end
