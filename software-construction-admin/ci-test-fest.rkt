#lang at-exp racket

(require "cmdline.rkt"
         "assignments.rkt"
         "assignment-paths.rkt"
         "team-repos.rkt"
         "util.rkt"
         "testing.rkt"
         "tests.rkt"
         "logger.rkt")

(define expected-valid-test-count 5)

(define (get-pre-validated-tests-by-team assign-number)
  (define all-tests
    (directory->tests (assign-number->validated-tests-path assign-number)))
  (for/hash/fold ([test (in-list all-tests)])
    #:combine cons
    #:default empty
    (values (test-input-file->team-name (test-input-file test))
            test)))

(module+ main
  (match-define (cons (hash-table ['major major-number]
                                  ['minor minor-number]
                                  ['test-exe (app path->complete-path test-exe-path)]
                                  ['team team-name])
                      args)
    (command-line/declarative
     #:once-each
     [("-M" "--Major")
      'major
      "Assignment major number. E.g. for 5.2 this is 5."
      #:collect {"number" take-latest #f}
      #:mandatory]
     [("-m" "--minor")
      'minor
      "Assignment minor number. E.g. for 5.2 this is 2."
      #:collect {"number" take-latest #f}
      #:mandatory]
     [("-t" "--test-exe")
      'test-exe
      "Path to executable to test."
      #:collect {"path" take-latest #f}
      #:mandatory]
     [("-n" "--team-name")
      'team
      "Team name to report test validity results for."
      #:collect {"path" take-latest #f}
      #:mandatory]))

  (define assign-number (cons major-number minor-number))
  (define validated-tests-by-team (get-pre-validated-tests-by-team assign-number))
  (log-fest-info
   @~a{
       Running tests for assignment @(assign-number->string assign-number) on team @team-name's @;
       submission executable @(pretty-path test-exe-path)
       })
  (define failed-peer-tests
    (test-failures-for test-exe-path
                       (assign-number->oracle-path assign-number)
                       validated-tests-by-team))
  (log-fest-info @~a{Done running tests.})


  (define valid-tests-by-team
    (length (hash-ref validated-tests-by-team
                      team-name
                      empty)))
  (define enough-valid-tests? (>= valid-tests-by-team expected-valid-test-count))

  (define total-test-count (test-set-count-tests validated-tests-by-team))
  (define failed-count (test-set-count-tests failed-peer-tests))
  (define failed? (not (zero? failed-count)))
  (log-fest-info
   @~a{


       =======================================================
       Test fest summary for assignment @(assign-number->string assign-number): @(if failed?
                                                                                     "FAIL"
                                                                                     "OK")
       Submitted @valid-tests-by-team / @(max-number-tests assign-number) valid tests
       Failed @failed-count / @total-test-count peer tests
       =======================================================
       })
  (exit
   (cond [failed?
          (log-fest-info
           @~a{

               Failed tests:
               @(pretty-format
                 (for/hash ([(group tests) (in-hash failed-peer-tests)])
                   (values group
                           (map (λ (t) (basename (test-input-file t)))
                                tests))))
               })
          1]
         [(not enough-valid-tests?) 1]
         [else 0])))
