Feature: Fact checking policies
  In order to ensure we're not publishing any inaccuracies in our policies
  As someone involved in drafting policy
  I want to garner comments on a draft policy from other individuals

Scenario: Departmental editor requests fact checking
  Given I am an writer called "Bob"
  And a draft policy "Standard Beard Lengths" exists
  When I request that "fact-checker@example.com" fact checks the policy "Standard Beard Lengths"
  Then "fact-checker@example.com" should be notified by email that "Bob" has requested a fact check for "Standard Beard Lengths"

Scenario: Fact checker views the draft policy
  Given "fact-checker@example.com" has received an email requesting they fact check a draft publication "Check me"
  When "fact-checker@example.com" clicks the email link to the draft policy
  Then they should see the draft publication "Check me"

Scenario: Fact checker enters feedback
  Given "fact-checker@example.com" has received an email requesting they fact check a draft publication "Check me"
  When "fact-checker@example.com" clicks the email link to the draft policy
  And they provide feedback "We cannot establish the moral character of all dogs"
  Then they should be notified "Your feedback has been saved"

Scenario: Policy writer reviews fact checker comments
  Given a fact checker has commented "This looks good" on the draft publication "Check me"
  When I am a writer
  And I visit the list of draft policies
  And I click on the policy "Check me"
  Then I should see the fact checking feedback "This looks good"

Scenario: Departmental editor reviews fact checker comments
  Given a fact checker has commented "This looks good" on the draft publication "Check me"
  When I am an editor
  And I visit the list of draft policies
  And I click on the policy "Check me"
  Then I should see the fact checking feedback "This looks good"