FactoryGirl.define do
  factory :definition do
    sequence(:name) { |n| "name#{n}" }
    description { 'Test workflow definition'}
    data {
      {
          'jobs': [
                      {
                          'name': 'apple',
                          'image': 'timer:mine',
                          'cmd': '/timer.rb',
                          'args': ['30s']
                      },
                      {
                          'name': 'banana',
                          'image': 'timer:mine',
                          'cmd': '/timer.rb',
                          'args': ['2m']
                      },
                      {
                          'name': 'cantaloupe',
                          'image': 'timer:mine',
                          'cmd': '/timer.rb',
                          'args': ['20s']
                      },
                      {
                          'name': 'dragonfruit',
                          'image': 'timer:mine',
                          'cmd': '/timer.rb',
                          'args': ['10s']
                      }
                  ],
          'neighbors': {
              'apple': [ 'banana', 'cantaloupe' ],
              'banana': [ 'dragonfruit' ],
              'cantaloupe': [ 'dragonfruit' ]
          }
      }
    }
    factory :definition_empty_data, class: Definition do
      data { {} }
    end

    factory :definition_bad_data, class: Definition do
      data { { 'fake': 'data' } }
    end

    factory :definition_multi_root, class: Definition do
      data {
        {
            'jobs': [
                        {
                            'name': 'apple',
                            'image': 'timer:mine',
                            'cmd': '/timer.rb',
                            'args': ['30s']
                        },
                        {
                            'name': 'banana',
                            'image': 'timer:mine',
                            'cmd': '/timer.rb',
                            'args': ['2m']
                        },
                        {
                            'name': 'cantaloupe',
                            'image': 'timer:mine',
                            'cmd': '/timer.rb',
                            'args': ['20s']
                        },
                        {
                            'name': 'dragonfruit',
                            'image': 'timer:mine',
                            'cmd': '/timer.rb',
                            'args': ['10s']
                        }
                    ],
            'neighbors': {
                'apple': [ 'cantaloupe' ],
                'banana': [ 'cantaloupe' ],
                'cantaloupe': [ 'dragonfruit' ]
            }
        }
      }
    end
  end
end
