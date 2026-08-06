import unittest


unittest.test_case = unittest.TestCase
unittest.TestCase.assert_equal = unittest.TestCase.assertEqual
unittest.TestCase.assert_greater = unittest.TestCase.assertGreater
unittest.TestCase.assert_in = unittest.TestCase.assertIn
unittest.TestCase.assert_is_not_none = unittest.TestCase.assertIsNotNone
