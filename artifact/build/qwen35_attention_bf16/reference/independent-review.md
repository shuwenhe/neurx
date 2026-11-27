# Independent review — /root/attention_reference_review

Read-only tools accessible; source and evidence actually inspected, no GPU tests run by reviewer. No P1 mathematical-body/oracle defect found. Two P2 findings: observation-off still retained hooks/wrappers; approved trace metrics incomplete. Both reproduced by two RED tests in review-fixes-red.log, then corrected. Fully uninstrumented control now has zero hooks and no wrappers; observer CPU copies are excluded from dispatch events. Required near-zero/nonfinite-location/BF16 bit/ULP/stride/layout/logical GPU byte fields added. Full suite7/7 GREEN (phase-a-final-reviewed.log).

Review supports narrow reference structure/dtype evidence only, not Native numerical acceptance or a frozen budget. Candidate PARTIAL/REVIEW_REQUIRED and pending norm/softmax/composition budgets remain appropriate. Review is not human approval.
