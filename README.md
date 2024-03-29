# Ruby test task for GlobalLogic

Write a migration and ActiveRecord model that tracks restaurant reservations. Assume there is a table in your relational database named "reservations".  
Reservations have a start time, an end time and a table number. 

Write some ActiveRecord validations that check new reservations for overbooking of the
same table in the restaurant. For example, table #10 cannot have 2 reservations 
for the same period of time. This validation(s) should check time overlap for both 
record creation and updates. 

Unit tests are a must to make sure your double booking validations are working. 
(rspec and unittests)

## Check

    $ git clone git@github.com:shhavel/ruby_test_task_for_globallogic.git
    $ cd ruby_test_task_for_globallogic
    $ bundle
    $ rspec spec/reservation_spec.rb
