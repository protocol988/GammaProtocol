import {OracleInstance} from '../build/types/truffle-types'

const {expectEvent, expectRevert} = require('@openzeppelin/test-helpers')

const Oracle = artifacts.require('Oracle.sol')
// address(0)
const ZERO_ADDR = '0x0000000000000000000000000000000000000000'

contract('Oracle', ([owner]) => {
  // Oracle module
  let oracle: OracleInstance

  before('Deployment', async () => {
    // deploy Whitelist module
    oracle = await Oracle.new({from: owner})
  })

  describe('oracle', () => {
    it('oracle', async () => {
      //empty
    })
  })
})