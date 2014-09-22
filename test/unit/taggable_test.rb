require 'test_helper'

class TaggableTest < ActiveSupport::TestCase

  test "tagging enabled" do
    assert Person.is_taggable?
    assert Model.is_taggable?
    assert Assay.is_taggable?

    person = Person.new
    model = Model.new
    assay = Assay.new
    assert person.is_taggable?
    assert model.is_taggable?
    assert assay.is_taggable?


    with_config_value :tagging_enabled,false do
      refute Person.is_taggable?
      refute Model.is_taggable?
      refute Assay.is_taggable?
      refute person.is_taggable?
      refute model.is_taggable?
      refute assay.is_taggable?

    end
  end

  test "tag_with" do
     p=Factory :person
     User.current_user = p.user
     assert_equal 0,p.expertise.size
     assert_difference("Annotation.count",2) do
       assert_difference("TextValue.count",2) do
         p.tag_with ["golf","fishing"],"expertise"
       end
     end
     p.reload
     assert_equal ["golf","fishing"].sort, p.expertise.collect{|t| t.text}.sort
  end

  test "tag_with_params" do
    p=Factory :person
     User.current_user = p.user
     assert_equal 0,p.expertise.size
     assert_difference("Annotation.count",2) do
       assert_difference("TextValue.count",2) do
         params={:expertise_autocompleter_selected_ids=>[],
                 :expertise_autocompleter_unrecognized_items=>["golf","fishing"]
         }
         p.tag_with_params params,"expertise"
       end
     end
     p.reload
     assert_equal ["golf","fishing"].sort, p.expertise.collect{|t| t.text}.sort
  end

  test "tag_with changed response" do
    p=Factory :person
    User.current_user = p.user
    p.save!
    attr="expertise"
    p.tag_with(["golf","fishing"],attr)
    p.save!
    assert !p.annotations_with_attribute(attr).empty?
    assert !p.tag_with(["golf","fishing"],attr)
    assert p.tag_with(["golf","fishing","sparrow"],attr)
    assert p.tag_with(["golf","fishing"],attr)
  end


end