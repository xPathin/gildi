//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Aggregator
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const aggregatorAbi = [
  { type: 'constructor', inputs: [], stateMutability: 'nonpayable' },
  { type: 'error', inputs: [], name: 'AccessControlBadConfirmation' },
  {
    type: 'error',
    inputs: [
      { name: 'account', internalType: 'address', type: 'address' },
      { name: 'neededRole', internalType: 'bytes32', type: 'bytes32' },
    ],
    name: 'AccessControlUnauthorizedAccount',
  },
  { type: 'error', inputs: [], name: 'FailedCall' },
  { type: 'error', inputs: [], name: 'IncorrectMsgValue' },
  { type: 'error', inputs: [], name: 'IndexOutOfRange' },
  {
    type: 'error',
    inputs: [
      { name: 'balance', internalType: 'uint256', type: 'uint256' },
      { name: 'needed', internalType: 'uint256', type: 'uint256' },
    ],
    name: 'InsufficientBalance',
  },
  { type: 'error', inputs: [], name: 'InsufficientLiquidity' },
  { type: 'error', inputs: [], name: 'InsufficientReceiveAmount' },
  { type: 'error', inputs: [], name: 'InvalidInitialization' },
  { type: 'error', inputs: [], name: 'NativeNotAllowed' },
  { type: 'error', inputs: [], name: 'NoAdapters' },
  { type: 'error', inputs: [], name: 'NoValidRoute' },
  { type: 'error', inputs: [], name: 'NotEnoughSourceTokensForBestRoute' },
  { type: 'error', inputs: [], name: 'NotInitializing' },
  {
    type: 'error',
    inputs: [{ name: 'token', internalType: 'address', type: 'address' }],
    name: 'PurchaseTokenNotAllowed',
  },
  { type: 'error', inputs: [], name: 'ReentrancyGuardReentrantCall' },
  {
    type: 'error',
    inputs: [{ name: 'token', internalType: 'address', type: 'address' }],
    name: 'SafeERC20FailedOperation',
  },
  { type: 'error', inputs: [], name: 'SlippageExceeded' },
  { type: 'error', inputs: [], name: 'SwapOutFailed' },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'adapter',
        internalType: 'contract IGildiExchangeSwapAdapter',
        type: 'address',
        indexed: false,
      },
    ],
    name: 'AdapterAdded',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'adapter',
        internalType: 'contract IGildiExchangeSwapAdapter',
        type: 'address',
        indexed: false,
      },
    ],
    name: 'AdapterRemoved',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'token',
        internalType: 'address',
        type: 'address',
        indexed: false,
      },
      { name: 'allowed', internalType: 'bool', type: 'bool', indexed: false },
    ],
    name: 'AllowedSwapInTokenSet',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'version',
        internalType: 'uint64',
        type: 'uint64',
        indexed: false,
      },
    ],
    name: 'Initialized',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'marketplaceToken',
        internalType: 'address',
        type: 'address',
        indexed: true,
      },
      {
        name: 'recipient',
        internalType: 'address',
        type: 'address',
        indexed: false,
      },
      {
        name: 'sourceAmount',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false,
      },
      { name: 'swapped', internalType: 'bool', type: 'bool', indexed: false },
      {
        name: 'targetToken',
        internalType: 'address',
        type: 'address',
        indexed: false,
      },
      {
        name: 'targetAmount',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false,
      },
    ],
    name: 'MarketplaceLeftoverReturned',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      { name: 'allow', internalType: 'bool', type: 'bool', indexed: false },
    ],
    name: 'PurchaseAllowNativeSet',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      { name: 'role', internalType: 'bytes32', type: 'bytes32', indexed: true },
      {
        name: 'previousAdminRole',
        internalType: 'bytes32',
        type: 'bytes32',
        indexed: true,
      },
      {
        name: 'newAdminRole',
        internalType: 'bytes32',
        type: 'bytes32',
        indexed: true,
      },
    ],
    name: 'RoleAdminChanged',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      { name: 'role', internalType: 'bytes32', type: 'bytes32', indexed: true },
      {
        name: 'account',
        internalType: 'address',
        type: 'address',
        indexed: true,
      },
      {
        name: 'sender',
        internalType: 'address',
        type: 'address',
        indexed: true,
      },
    ],
    name: 'RoleGranted',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      { name: 'role', internalType: 'bytes32', type: 'bytes32', indexed: true },
      {
        name: 'account',
        internalType: 'address',
        type: 'address',
        indexed: true,
      },
      {
        name: 'sender',
        internalType: 'address',
        type: 'address',
        indexed: true,
      },
    ],
    name: 'RoleRevoked',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'token',
        internalType: 'address',
        type: 'address',
        indexed: false,
      },
      { name: 'allowed', internalType: 'bool', type: 'bool', indexed: false },
    ],
    name: 'SourceTokenSet',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'sourceToken',
        internalType: 'address',
        type: 'address',
        indexed: true,
      },
      {
        name: 'targetToken',
        internalType: 'address',
        type: 'address',
        indexed: true,
      },
      {
        name: 'sourceAmount',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false,
      },
      {
        name: 'targetAmount',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false,
      },
      {
        name: 'recipient',
        internalType: 'address',
        type: 'address',
        indexed: false,
      },
      {
        name: 'adapter',
        internalType: 'address',
        type: 'address',
        indexed: false,
      },
      {
        name: 'route',
        internalType: 'struct IGildiExchangeSwapAdapter.QuoteRoute',
        type: 'tuple',
        components: [
          {
            name: 'marketplaceAdapter',
            internalType: 'address',
            type: 'address',
          },
          { name: 'route', internalType: 'address[]', type: 'address[]' },
          { name: 'fees', internalType: 'uint128[]', type: 'uint128[]' },
          { name: 'amounts', internalType: 'uint128[]', type: 'uint128[]' },
          {
            name: 'virtualAmountsWithoutSlippage',
            internalType: 'uint128[]',
            type: 'uint128[]',
          },
        ],
        indexed: false,
      },
    ],
    name: 'SwapExecuted',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'sourceToken',
        internalType: 'address',
        type: 'address',
        indexed: true,
      },
      {
        name: 'targetToken',
        internalType: 'address',
        type: 'address',
        indexed: true,
      },
      {
        name: 'amount',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false,
      },
      {
        name: 'expectedOutput',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false,
      },
      {
        name: 'selectedAdapter',
        internalType: 'address',
        type: 'address',
        indexed: false,
      },
    ],
    name: 'SwapRouteSelected',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'wnative',
        internalType: 'address',
        type: 'address',
        indexed: false,
      },
    ],
    name: 'WrappedNativeSet',
  },
  {
    type: 'function',
    inputs: [],
    name: 'ADMIN_ROLE',
    outputs: [{ name: '', internalType: 'bytes32', type: 'bytes32' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'DEFAULT_ADMIN_ROLE',
    outputs: [{ name: '', internalType: 'bytes32', type: 'bytes32' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [
      {
        name: '_adapter',
        internalType: 'contract IGildiExchangeSwapAdapter',
        type: 'address',
      },
    ],
    name: 'addAdapter',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      { name: '_releaseId', internalType: 'uint256', type: 'uint256' },
      { name: '_amount', internalType: 'uint256', type: 'uint256' },
      { name: '_buyer', internalType: 'address', type: 'address' },
      { name: '_sourceToken', internalType: 'address', type: 'address' },
    ],
    name: 'estimatePurchase',
    outputs: [
      { name: 'sourceNeeded', internalType: 'uint256', type: 'uint256' },
      { name: 'releaseCurrency', internalType: 'address', type: 'address' },
      {
        name: 'quoteRoute',
        internalType: 'struct IGildiExchangeSwapAdapter.QuoteRoute',
        type: 'tuple',
        components: [
          {
            name: 'marketplaceAdapter',
            internalType: 'address',
            type: 'address',
          },
          { name: 'route', internalType: 'address[]', type: 'address[]' },
          { name: 'fees', internalType: 'uint128[]', type: 'uint128[]' },
          { name: 'amounts', internalType: 'uint128[]', type: 'uint128[]' },
          {
            name: 'virtualAmountsWithoutSlippage',
            internalType: 'uint128[]',
            type: 'uint128[]',
          },
        ],
      },
      { name: 'totalPriceUsd', internalType: 'uint256', type: 'uint256' },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'getAdapters',
    outputs: [
      {
        name: '',
        internalType: 'contract IGildiExchangeSwapAdapter[]',
        type: 'address[]',
      },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'getAllowedPurchaseTokens',
    outputs: [{ name: '', internalType: 'address[]', type: 'address[]' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'getGildiExchange',
    outputs: [
      { name: '', internalType: 'contract IGildiExchange', type: 'address' },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [{ name: '_releaseId', internalType: 'uint256', type: 'uint256' }],
    name: 'getMarketplaceToken',
    outputs: [{ name: '', internalType: 'address', type: 'address' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'getPurchaseAllowNative',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [{ name: 'role', internalType: 'bytes32', type: 'bytes32' }],
    name: 'getRoleAdmin',
    outputs: [{ name: '', internalType: 'bytes32', type: 'bytes32' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'getWrappedNative',
    outputs: [{ name: '', internalType: 'address', type: 'address' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [
      { name: 'role', internalType: 'bytes32', type: 'bytes32' },
      { name: 'account', internalType: 'address', type: 'address' },
    ],
    name: 'grantRole',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      { name: 'role', internalType: 'bytes32', type: 'bytes32' },
      { name: 'account', internalType: 'address', type: 'address' },
    ],
    name: 'hasRole',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [
      { name: '_gildiExchange', internalType: 'address', type: 'address' },
      { name: '_wNativeAddress', internalType: 'address', type: 'address' },
      {
        name: '_initialDefaultAdmin',
        internalType: 'address',
        type: 'address',
      },
      {
        name: '_initialContractAdmin',
        internalType: 'address',
        type: 'address',
      },
    ],
    name: 'initialize',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [{ name: '_token', internalType: 'address', type: 'address' }],
    name: 'isPurchaseTokenAllowed',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [
      { name: '_amount', internalType: 'uint256', type: 'uint256' },
      { name: '_sourceCurrency', internalType: 'address', type: 'address' },
      { name: '_targetToken', internalType: 'address', type: 'address' },
    ],
    name: 'previewSwapOut',
    outputs: [
      { name: 'hasValidRoute', internalType: 'bool', type: 'bool' },
      {
        name: 'expectedTargetAmount',
        internalType: 'uint256',
        type: 'uint256',
      },
      {
        name: 'bestRoute',
        internalType: 'struct IGildiExchangeSwapAdapter.QuoteRoute',
        type: 'tuple',
        components: [
          {
            name: 'marketplaceAdapter',
            internalType: 'address',
            type: 'address',
          },
          { name: 'route', internalType: 'address[]', type: 'address[]' },
          { name: 'fees', internalType: 'uint128[]', type: 'uint128[]' },
          { name: 'amounts', internalType: 'uint128[]', type: 'uint128[]' },
          {
            name: 'virtualAmountsWithoutSlippage',
            internalType: 'uint128[]',
            type: 'uint128[]',
          },
        ],
      },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [
      { name: '_releaseId', internalType: 'uint256', type: 'uint256' },
      { name: '_amount', internalType: 'uint256', type: 'uint256' },
      { name: '_sourceToken', internalType: 'address', type: 'address' },
      { name: '_sourceMaxAmount', internalType: 'uint256', type: 'uint256' },
    ],
    name: 'purchase',
    outputs: [
      { name: 'amountUsdSpent', internalType: 'uint256', type: 'uint256' },
    ],
    stateMutability: 'payable',
  },
  {
    type: 'function',
    inputs: [{ name: 'index', internalType: 'uint256', type: 'uint256' }],
    name: 'removeAdapter',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      {
        name: 'adapter',
        internalType: 'contract IGildiExchangeSwapAdapter',
        type: 'address',
      },
    ],
    name: 'removeAdapter',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      { name: 'role', internalType: 'bytes32', type: 'bytes32' },
      { name: 'callerConfirmation', internalType: 'address', type: 'address' },
    ],
    name: 'renounceRole',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      { name: 'role', internalType: 'bytes32', type: 'bytes32' },
      { name: 'account', internalType: 'address', type: 'address' },
    ],
    name: 'revokeRole',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      { name: '_token', internalType: 'address', type: 'address' },
      { name: '_allowed', internalType: 'bool', type: 'bool' },
    ],
    name: 'setAllowedPurchaseToken',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [{ name: '_allow', internalType: 'bool', type: 'bool' }],
    name: 'setPurchaseAllowNative',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [{ name: '_wnative', internalType: 'address', type: 'address' }],
    name: 'setWrappedNative',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [{ name: 'interfaceId', internalType: 'bytes4', type: 'bytes4' }],
    name: 'supportsInterface',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [
      { name: '_amount', internalType: 'uint256', type: 'uint256' },
      { name: '_sourceCurrency', internalType: 'address', type: 'address' },
      { name: '_targetToken', internalType: 'address', type: 'address' },
      { name: '_minTargetAmount', internalType: 'uint256', type: 'uint256' },
      { name: '_recipient', internalType: 'address', type: 'address' },
    ],
    name: 'swapOut',
    outputs: [
      { name: 'targetReceived', internalType: 'uint256', type: 'uint256' },
    ],
    stateMutability: 'nonpayable',
  },
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ERC20
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const erc20Abi = [
  {
    type: 'function',
    inputs: [],
    name: 'name',
    outputs: [{ name: '', internalType: 'string', type: 'string' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'symbol',
    outputs: [{ name: '', internalType: 'string', type: 'string' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'decimals',
    outputs: [{ name: '', internalType: 'uint8', type: 'uint8' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [{ name: 'owner', internalType: 'address', type: 'address' }],
    name: 'balanceOf',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [
      { name: 'owner', internalType: 'address', type: 'address' },
      { name: 'spender', internalType: 'address', type: 'address' },
    ],
    name: 'allowance',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [
      { name: 'spender', internalType: 'address', type: 'address' },
      { name: 'value', internalType: 'uint256', type: 'uint256' },
    ],
    name: 'approve',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'nonpayable',
  },
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Exchange
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const exchangeAbi = [
  { type: 'constructor', inputs: [], stateMutability: 'nonpayable' },
  { type: 'error', inputs: [], name: 'AccessControlBadConfirmation' },
  {
    type: 'error',
    inputs: [
      { name: 'account', internalType: 'address', type: 'address' },
      { name: 'neededRole', internalType: 'bytes32', type: 'bytes32' },
    ],
    name: 'AccessControlUnauthorizedAccount',
  },
  { type: 'error', inputs: [], name: 'EnforcedPause' },
  { type: 'error', inputs: [], name: 'ExpectedPause' },
  {
    type: 'error',
    inputs: [
      { name: 'requested', internalType: 'uint256', type: 'uint256' },
      { name: 'available', internalType: 'uint256', type: 'uint256' },
    ],
    name: 'InsufficientQuantity',
  },
  { type: 'error', inputs: [], name: 'InvalidCaller' },
  { type: 'error', inputs: [], name: 'InvalidInitialization' },
  { type: 'error', inputs: [], name: 'NotAllowed' },
  {
    type: 'error',
    inputs: [
      { name: 'requested', internalType: 'uint256', type: 'uint256' },
      { name: 'available', internalType: 'uint256', type: 'uint256' },
    ],
    name: 'NotEnoughTokensInListings',
  },
  { type: 'error', inputs: [], name: 'NotInitializing' },
  { type: 'error', inputs: [], name: 'ParamError' },
  { type: 'error', inputs: [], name: 'PurchaseError' },
  { type: 'error', inputs: [], name: 'ReentrancyGuardReentrantCall' },
  {
    type: 'error',
    inputs: [{ name: 'releaseId', internalType: 'uint256', type: 'uint256' }],
    name: 'ReleaseNotFound',
  },
  {
    type: 'error',
    inputs: [{ name: 'releaseId', internalType: 'uint256', type: 'uint256' }],
    name: 'ReleaseStateError',
  },
  {
    type: 'error',
    inputs: [{ name: 'token', internalType: 'address', type: 'address' }],
    name: 'SafeERC20FailedOperation',
  },
  { type: 'error', inputs: [], name: 'SetupError' },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'askDecimals',
        internalType: 'uint8',
        type: 'uint8',
        indexed: false,
      },
    ],
    name: 'AskDecimalsSet',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'releaseId',
        internalType: 'uint256',
        type: 'uint256',
        indexed: true,
      },
    ],
    name: 'FeesUpdated',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'releaseId',
        internalType: 'uint256',
        type: 'uint256',
        indexed: true,
      },
      {
        name: 'seller',
        internalType: 'address',
        type: 'address',
        indexed: true,
      },
      {
        name: 'assetQuantities',
        internalType: 'uint256[]',
        type: 'uint256[]',
        indexed: false,
      },
      {
        name: 'assetPrices',
        internalType: 'uint256[]',
        type: 'uint256[]',
        indexed: false,
      },
      {
        name: 'maxBuy',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false,
      },
      {
        name: 'startTime',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false,
      },
      {
        name: 'duration',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false,
      },
      {
        name: 'whitelistEnabled',
        internalType: 'bool',
        type: 'bool',
        indexed: false,
      },
      {
        name: 'whitelistDuration',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false,
      },
      {
        name: 'saleCurrency',
        internalType: 'address',
        type: 'address',
        indexed: false,
      },
      {
        name: 'payoutCurrency',
        internalType: 'address',
        type: 'address',
        indexed: false,
      },
      {
        name: 'saleFees',
        internalType: 'struct IGildiExchange.FeeDistribution[]',
        type: 'tuple[]',
        components: [
          {
            name: 'feeReceiver',
            internalType: 'struct IGildiExchange.Receiver',
            type: 'tuple',
            components: [
              {
                name: 'receiverAddress',
                internalType: 'address',
                type: 'address',
              },
              {
                name: 'payoutCurrency',
                internalType: 'address',
                type: 'address',
              },
              { name: 'value', internalType: 'uint16', type: 'uint16' },
            ],
          },
          {
            name: 'subFeeReceivers',
            internalType: 'struct IGildiExchange.Receiver[]',
            type: 'tuple[]',
            components: [
              {
                name: 'receiverAddress',
                internalType: 'address',
                type: 'address',
              },
              {
                name: 'payoutCurrency',
                internalType: 'address',
                type: 'address',
              },
              { name: 'value', internalType: 'uint16', type: 'uint16' },
            ],
          },
        ],
        indexed: false,
      },
    ],
    name: 'InitialSaleCreated',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'releaseId',
        internalType: 'uint256',
        type: 'uint256',
        indexed: true,
      },
    ],
    name: 'InitialSaleEnded',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'version',
        internalType: 'uint64',
        type: 'uint64',
        indexed: false,
      },
    ],
    name: 'Initialized',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'marketplaceCurrency',
        internalType: 'address',
        type: 'address',
        indexed: false,
      },
    ],
    name: 'MarketplaceCurrencySet',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'account',
        internalType: 'address',
        type: 'address',
        indexed: false,
      },
    ],
    name: 'Paused',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'releaseId',
        internalType: 'uint256',
        type: 'uint256',
        indexed: true,
      },
      {
        name: 'buyer',
        internalType: 'address',
        type: 'address',
        indexed: true,
      },
      {
        name: 'seller',
        internalType: 'address',
        type: 'address',
        indexed: true,
      },
      {
        name: 'operator',
        internalType: 'address',
        type: 'address',
        indexed: false,
      },
      {
        name: 'listingId',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false,
      },
      {
        name: 'priceInUSD',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false,
      },
      {
        name: 'quantity',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false,
      },
      {
        name: 'priceInAsset',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false,
      },
      {
        name: 'asset',
        internalType: 'address',
        type: 'address',
        indexed: false,
      },
    ],
    name: 'Purchased',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'releaseId',
        internalType: 'uint256',
        type: 'uint256',
        indexed: true,
      },
      { name: 'isActive', internalType: 'bool', type: 'bool', indexed: false },
    ],
    name: 'ReleaseActiveStateChanged',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'releaseId',
        internalType: 'uint256',
        type: 'uint256',
        indexed: true,
      },
    ],
    name: 'ReleaseCancellationStarted',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'releaseId',
        internalType: 'uint256',
        type: 'uint256',
        indexed: true,
      },
    ],
    name: 'ReleaseCancelled',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'releaseId',
        internalType: 'uint256',
        type: 'uint256',
        indexed: true,
      },
    ],
    name: 'ReleaseInitialized',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      { name: 'role', internalType: 'bytes32', type: 'bytes32', indexed: true },
      {
        name: 'previousAdminRole',
        internalType: 'bytes32',
        type: 'bytes32',
        indexed: true,
      },
      {
        name: 'newAdminRole',
        internalType: 'bytes32',
        type: 'bytes32',
        indexed: true,
      },
    ],
    name: 'RoleAdminChanged',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      { name: 'role', internalType: 'bytes32', type: 'bytes32', indexed: true },
      {
        name: 'account',
        internalType: 'address',
        type: 'address',
        indexed: true,
      },
      {
        name: 'sender',
        internalType: 'address',
        type: 'address',
        indexed: true,
      },
    ],
    name: 'RoleGranted',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      { name: 'role', internalType: 'bytes32', type: 'bytes32', indexed: true },
      {
        name: 'account',
        internalType: 'address',
        type: 'address',
        indexed: true,
      },
      {
        name: 'sender',
        internalType: 'address',
        type: 'address',
        indexed: true,
      },
    ],
    name: 'RoleRevoked',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'account',
        internalType: 'address',
        type: 'address',
        indexed: false,
      },
    ],
    name: 'Unpaused',
  },
  { type: 'fallback', stateMutability: 'payable' },
  {
    type: 'function',
    inputs: [],
    name: 'DEFAULT_ADMIN_ROLE',
    outputs: [{ name: '', internalType: 'bytes32', type: 'bytes32' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'DEFAULT_SLIPPAGE_BPS',
    outputs: [{ name: '', internalType: 'uint16', type: 'uint16' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [
      { name: '_releaseId', internalType: 'uint256', type: 'uint256' },
      { name: '_address', internalType: 'address', type: 'address' },
    ],
    name: 'canBuy',
    outputs: [
      { name: 'buyAllowed', internalType: 'bool', type: 'bool' },
      { name: 'maxBuyAmount', internalType: 'uint256', type: 'uint256' },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [
      { name: '_releaseIds', internalType: 'uint256[]', type: 'uint256[]' },
    ],
    name: 'canSell',
    outputs: [{ name: '', internalType: 'bool[]', type: 'bool[]' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [{ name: '_listingId', internalType: 'uint256', type: 'uint256' }],
    name: 'cancelListing',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      { name: '_releaseId', internalType: 'uint256', type: 'uint256' },
      { name: '_batchSize', internalType: 'uint256', type: 'uint256' },
    ],
    name: 'cancelRelease',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      {
        name: '_params',
        internalType: 'struct GildiExchange.InitialSaleParams',
        type: 'tuple',
        components: [
          { name: 'releaseId', internalType: 'uint256', type: 'uint256' },
          {
            name: 'assetQuantities',
            internalType: 'uint256[]',
            type: 'uint256[]',
          },
          { name: 'assetPrices', internalType: 'uint256[]', type: 'uint256[]' },
          { name: 'seller', internalType: 'address', type: 'address' },
          { name: 'maxBuy', internalType: 'uint256', type: 'uint256' },
          { name: 'start', internalType: 'uint256', type: 'uint256' },
          { name: 'duration', internalType: 'uint256', type: 'uint256' },
          { name: 'whitelist', internalType: 'bool', type: 'bool' },
          {
            name: 'whitelistAddresses',
            internalType: 'address[]',
            type: 'address[]',
          },
          {
            name: 'whitelistDuration',
            internalType: 'uint256',
            type: 'uint256',
          },
          {
            name: 'initialSaleCurrency',
            internalType: 'address',
            type: 'address',
          },
          { name: 'payoutCurrency', internalType: 'address', type: 'address' },
          { name: 'fundsReceiver', internalType: 'address', type: 'address' },
          {
            name: 'fees',
            internalType: 'struct IGildiExchange.FeeDistribution[]',
            type: 'tuple[]',
            components: [
              {
                name: 'feeReceiver',
                internalType: 'struct IGildiExchange.Receiver',
                type: 'tuple',
                components: [
                  {
                    name: 'receiverAddress',
                    internalType: 'address',
                    type: 'address',
                  },
                  {
                    name: 'payoutCurrency',
                    internalType: 'address',
                    type: 'address',
                  },
                  { name: 'value', internalType: 'uint16', type: 'uint16' },
                ],
              },
              {
                name: 'subFeeReceivers',
                internalType: 'struct IGildiExchange.Receiver[]',
                type: 'tuple[]',
                components: [
                  {
                    name: 'receiverAddress',
                    internalType: 'address',
                    type: 'address',
                  },
                  {
                    name: 'payoutCurrency',
                    internalType: 'address',
                    type: 'address',
                  },
                  { name: 'value', internalType: 'uint16', type: 'uint16' },
                ],
              },
            ],
          },
        ],
      },
    ],
    name: 'createInitialSale',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      { name: '_releaseId', internalType: 'uint256', type: 'uint256' },
      { name: '_seller', internalType: 'address', type: 'address' },
      { name: '_pricePerItem', internalType: 'uint256', type: 'uint256' },
      { name: '_quantity', internalType: 'uint256', type: 'uint256' },
      { name: '_payoutCurrency', internalType: 'address', type: 'address' },
      { name: '_fundsReceiver', internalType: 'address', type: 'address' },
      { name: '_slippageBps', internalType: 'uint16', type: 'uint16' },
    ],
    name: 'createListing',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      { name: '_releaseId', internalType: 'uint256', type: 'uint256' },
      { name: '_seller', internalType: 'address', type: 'address' },
      { name: '_pricePerItem', internalType: 'uint256', type: 'uint256' },
      { name: '_quantity', internalType: 'uint256', type: 'uint256' },
      { name: '_payoutCurrency', internalType: 'address', type: 'address' },
      { name: '_fundsReceiver', internalType: 'address', type: 'address' },
    ],
    name: 'createListing',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [{ name: '_releaseId', internalType: 'uint256', type: 'uint256' }],
    name: 'getActiveMarketplaceReleaseAsset',
    outputs: [{ name: '', internalType: 'address', type: 'address' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'getAppEnvironment',
    outputs: [
      {
        name: '',
        internalType: 'struct IGildiExchange.AppEnvironment',
        type: 'tuple',
        components: [
          {
            name: 'settings',
            internalType: 'struct IGildiExchange.AppSettings',
            type: 'tuple',
            components: [
              {
                name: 'priceAskDecimals',
                internalType: 'uint8',
                type: 'uint8',
              },
              {
                name: 'fees',
                internalType: 'struct IGildiExchange.FeeDistribution[]',
                type: 'tuple[]',
                components: [
                  {
                    name: 'feeReceiver',
                    internalType: 'struct IGildiExchange.Receiver',
                    type: 'tuple',
                    components: [
                      {
                        name: 'receiverAddress',
                        internalType: 'address',
                        type: 'address',
                      },
                      {
                        name: 'payoutCurrency',
                        internalType: 'address',
                        type: 'address',
                      },
                      { name: 'value', internalType: 'uint16', type: 'uint16' },
                    ],
                  },
                  {
                    name: 'subFeeReceivers',
                    internalType: 'struct IGildiExchange.Receiver[]',
                    type: 'tuple[]',
                    components: [
                      {
                        name: 'receiverAddress',
                        internalType: 'address',
                        type: 'address',
                      },
                      {
                        name: 'payoutCurrency',
                        internalType: 'address',
                        type: 'address',
                      },
                      { name: 'value', internalType: 'uint16', type: 'uint16' },
                    ],
                  },
                ],
              },
              {
                name: 'marketplaceCurrency',
                internalType: 'contract IERC20',
                type: 'address',
              },
              {
                name: 'maxBuyPerTransaction',
                internalType: 'uint256',
                type: 'uint256',
              },
              {
                name: 'gildiManager',
                internalType: 'contract IGildiManager',
                type: 'address',
              },
              {
                name: 'orderBook',
                internalType: 'contract IGildiExchangeOrderBook',
                type: 'address',
              },
              {
                name: 'gildiPriceOracle',
                internalType: 'contract IGildiPriceOracle',
                type: 'address',
              },
              {
                name: 'fundManager',
                internalType: 'contract IGildiExchangeFundManager',
                type: 'address',
              },
              {
                name: 'paymentProcessor',
                internalType: 'contract IGildiExchangePaymentProcessor',
                type: 'address',
              },
              {
                name: 'paymentAggregator',
                internalType: 'contract IGildiExchangePaymentAggregator',
                type: 'address',
              },
            ],
          },
          { name: 'basisPoints', internalType: 'uint16', type: 'uint16' },
          { name: 'adminRole', internalType: 'bytes32', type: 'bytes32' },
          {
            name: 'marketplaceManagerRole',
            internalType: 'bytes32',
            type: 'bytes32',
          },
          { name: 'claimerRole', internalType: 'bytes32', type: 'bytes32' },
        ],
      },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [{ name: '_releaseId', internalType: 'uint256', type: 'uint256' }],
    name: 'getInitialSaleByReleaseId',
    outputs: [
      {
        name: '',
        internalType: 'struct GildiExchange.InitialSale',
        type: 'tuple',
        components: [
          { name: 'active', internalType: 'bool', type: 'bool' },
          { name: 'whitelist', internalType: 'bool', type: 'bool' },
          { name: 'startTime', internalType: 'uint256', type: 'uint256' },
          { name: 'endTime', internalType: 'uint256', type: 'uint256' },
          { name: 'whitelistUntil', internalType: 'uint256', type: 'uint256' },
          { name: 'maxBuy', internalType: 'uint256', type: 'uint256' },
          { name: 'saleCurrency', internalType: 'address', type: 'address' },
          {
            name: 'fees',
            internalType: 'struct IGildiExchange.FeeDistribution[]',
            type: 'tuple[]',
            components: [
              {
                name: 'feeReceiver',
                internalType: 'struct IGildiExchange.Receiver',
                type: 'tuple',
                components: [
                  {
                    name: 'receiverAddress',
                    internalType: 'address',
                    type: 'address',
                  },
                  {
                    name: 'payoutCurrency',
                    internalType: 'address',
                    type: 'address',
                  },
                  { name: 'value', internalType: 'uint16', type: 'uint16' },
                ],
              },
              {
                name: 'subFeeReceivers',
                internalType: 'struct IGildiExchange.Receiver[]',
                type: 'tuple[]',
                components: [
                  {
                    name: 'receiverAddress',
                    internalType: 'address',
                    type: 'address',
                  },
                  {
                    name: 'payoutCurrency',
                    internalType: 'address',
                    type: 'address',
                  },
                  { name: 'value', internalType: 'uint16', type: 'uint16' },
                ],
              },
            ],
          },
        ],
      },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [{ name: '_releaseId', internalType: 'uint256', type: 'uint256' }],
    name: 'getReleaseById',
    outputs: [
      {
        name: '',
        internalType: 'struct GildiExchange.Release',
        type: 'tuple',
        components: [
          { name: 'releaseId', internalType: 'uint256', type: 'uint256' },
          {
            name: 'additionalFees',
            internalType: 'struct IGildiExchange.FeeDistribution[]',
            type: 'tuple[]',
            components: [
              {
                name: 'feeReceiver',
                internalType: 'struct IGildiExchange.Receiver',
                type: 'tuple',
                components: [
                  {
                    name: 'receiverAddress',
                    internalType: 'address',
                    type: 'address',
                  },
                  {
                    name: 'payoutCurrency',
                    internalType: 'address',
                    type: 'address',
                  },
                  { name: 'value', internalType: 'uint16', type: 'uint16' },
                ],
              },
              {
                name: 'subFeeReceivers',
                internalType: 'struct IGildiExchange.Receiver[]',
                type: 'tuple[]',
                components: [
                  {
                    name: 'receiverAddress',
                    internalType: 'address',
                    type: 'address',
                  },
                  {
                    name: 'payoutCurrency',
                    internalType: 'address',
                    type: 'address',
                  },
                  { name: 'value', internalType: 'uint16', type: 'uint16' },
                ],
              },
            ],
          },
          { name: 'initialized', internalType: 'bool', type: 'bool' },
          { name: 'active', internalType: 'bool', type: 'bool' },
          { name: 'isCancelling', internalType: 'bool', type: 'bool' },
        ],
      },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [{ name: '_releaseId', internalType: 'uint256', type: 'uint256' }],
    name: 'getReleaseFees',
    outputs: [
      {
        name: '',
        internalType: 'struct IGildiExchange.FeeDistribution[]',
        type: 'tuple[]',
        components: [
          {
            name: 'feeReceiver',
            internalType: 'struct IGildiExchange.Receiver',
            type: 'tuple',
            components: [
              {
                name: 'receiverAddress',
                internalType: 'address',
                type: 'address',
              },
              {
                name: 'payoutCurrency',
                internalType: 'address',
                type: 'address',
              },
              { name: 'value', internalType: 'uint16', type: 'uint16' },
            ],
          },
          {
            name: 'subFeeReceivers',
            internalType: 'struct IGildiExchange.Receiver[]',
            type: 'tuple[]',
            components: [
              {
                name: 'receiverAddress',
                internalType: 'address',
                type: 'address',
              },
              {
                name: 'payoutCurrency',
                internalType: 'address',
                type: 'address',
              },
              { name: 'value', internalType: 'uint16', type: 'uint16' },
            ],
          },
        ],
      },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [{ name: '_activeOnly', internalType: 'bool', type: 'bool' }],
    name: 'getReleaseIds',
    outputs: [{ name: '', internalType: 'uint256[]', type: 'uint256[]' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [{ name: 'role', internalType: 'bytes32', type: 'bytes32' }],
    name: 'getRoleAdmin',
    outputs: [{ name: '', internalType: 'bytes32', type: 'bytes32' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [{ name: '_releaseId', internalType: 'uint256', type: 'uint256' }],
    name: 'getWhitelist',
    outputs: [{ name: '', internalType: 'address[]', type: 'address[]' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [
      { name: 'role', internalType: 'bytes32', type: 'bytes32' },
      { name: 'account', internalType: 'address', type: 'address' },
    ],
    name: 'grantRole',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      { name: 'role', internalType: 'bytes32', type: 'bytes32' },
      { name: 'account', internalType: 'address', type: 'address' },
    ],
    name: 'hasRole',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [
      {
        name: '_initialDefaultAdmin',
        internalType: 'address',
        type: 'address',
      },
      { name: '_initialAdmin', internalType: 'address', type: 'address' },
      {
        name: '_initialMarketplaceManager',
        internalType: 'address',
        type: 'address',
      },
      {
        name: '_gildiManager',
        internalType: 'contract IGildiManager',
        type: 'address',
      },
      {
        name: '_marketplaceCurrency',
        internalType: 'contract IERC20',
        type: 'address',
      },
    ],
    name: 'initialize',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      { name: '_tokenId', internalType: 'uint256', type: 'uint256' },
      {
        name: '_additionalFees',
        internalType: 'struct IGildiExchange.FeeDistribution[]',
        type: 'tuple[]',
        components: [
          {
            name: 'feeReceiver',
            internalType: 'struct IGildiExchange.Receiver',
            type: 'tuple',
            components: [
              {
                name: 'receiverAddress',
                internalType: 'address',
                type: 'address',
              },
              {
                name: 'payoutCurrency',
                internalType: 'address',
                type: 'address',
              },
              { name: 'value', internalType: 'uint16', type: 'uint16' },
            ],
          },
          {
            name: 'subFeeReceivers',
            internalType: 'struct IGildiExchange.Receiver[]',
            type: 'tuple[]',
            components: [
              {
                name: 'receiverAddress',
                internalType: 'address',
                type: 'address',
              },
              {
                name: 'payoutCurrency',
                internalType: 'address',
                type: 'address',
              },
              { name: 'value', internalType: 'uint16', type: 'uint16' },
            ],
          },
        ],
      },
    ],
    name: 'initializeRelease',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [{ name: '_releaseId', internalType: 'uint256', type: 'uint256' }],
    name: 'isInInitialSale',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [
      { name: '', internalType: 'uint256', type: 'uint256' },
      { name: '', internalType: 'address', type: 'address' },
    ],
    name: 'isInitialSaleWhitelistBuyer',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [{ name: '_releaseId', internalType: 'uint256', type: 'uint256' }],
    name: 'isWhitelistSale',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [
      { name: '_listingId', internalType: 'uint256', type: 'uint256' },
      { name: '_newPricePerItem', internalType: 'uint256', type: 'uint256' },
      { name: '_newQuantity', internalType: 'uint256', type: 'uint256' },
      { name: '_payoutCurrency', internalType: 'address', type: 'address' },
      { name: '_fundsReceiver', internalType: 'address', type: 'address' },
      { name: '_slippageBps', internalType: 'uint16', type: 'uint16' },
    ],
    name: 'modifyListing',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      { name: '_listingId', internalType: 'uint256', type: 'uint256' },
      { name: '_newPricePerItem', internalType: 'uint256', type: 'uint256' },
      { name: '_newQuantity', internalType: 'uint256', type: 'uint256' },
      { name: '_payoutCurrency', internalType: 'address', type: 'address' },
      { name: '_fundsReceiver', internalType: 'address', type: 'address' },
    ],
    name: 'modifyListing',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [],
    name: 'pause',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [],
    name: 'paused',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [
      { name: '_releaseId', internalType: 'uint256', type: 'uint256' },
      { name: '_amount', internalType: 'uint256', type: 'uint256' },
      { name: '_maxTotalPrice', internalType: 'uint256', type: 'uint256' },
      { name: '_beneficiary', internalType: 'address', type: 'address' },
      { name: '_isProxyOperation', internalType: 'bool', type: 'bool' },
    ],
    name: 'purchase',
    outputs: [
      { name: 'amountSpent', internalType: 'uint256', type: 'uint256' },
      { name: 'amountUsdSpent', internalType: 'uint256', type: 'uint256' },
    ],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      { name: '_releaseId', internalType: 'uint256', type: 'uint256' },
      { name: '_priceInUsd', internalType: 'uint256', type: 'uint256' },
    ],
    name: 'quotePrice',
    outputs: [
      {
        name: 'activeMarketplaceReleaseAsset',
        internalType: 'address',
        type: 'address',
      },
      { name: 'priceInAsset', internalType: 'uint256', type: 'uint256' },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [
      { name: '_releaseId', internalType: 'uint256', type: 'uint256' },
      { name: '_amountToBuy', internalType: 'uint256', type: 'uint256' },
      { name: '_buyer', internalType: 'address', type: 'address' },
    ],
    name: 'quotePricePreview',
    outputs: [
      { name: '', internalType: 'uint256', type: 'uint256' },
      { name: '', internalType: 'address', type: 'address' },
      { name: '', internalType: 'uint256', type: 'uint256' },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    name: 'releases',
    outputs: [
      { name: 'releaseId', internalType: 'uint256', type: 'uint256' },
      { name: 'initialized', internalType: 'bool', type: 'bool' },
      { name: 'active', internalType: 'bool', type: 'bool' },
      { name: 'isCancelling', internalType: 'bool', type: 'bool' },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [
      { name: 'role', internalType: 'bytes32', type: 'bytes32' },
      { name: 'callerConfirmation', internalType: 'address', type: 'address' },
    ],
    name: 'renounceRole',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      { name: 'role', internalType: 'bytes32', type: 'bytes32' },
      { name: 'account', internalType: 'address', type: 'address' },
    ],
    name: 'revokeRole',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [{ name: '_askDecimals', internalType: 'uint8', type: 'uint8' }],
    name: 'setAskDecimals',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      {
        name: '_fees',
        internalType: 'struct IGildiExchange.FeeDistribution[]',
        type: 'tuple[]',
        components: [
          {
            name: 'feeReceiver',
            internalType: 'struct IGildiExchange.Receiver',
            type: 'tuple',
            components: [
              {
                name: 'receiverAddress',
                internalType: 'address',
                type: 'address',
              },
              {
                name: 'payoutCurrency',
                internalType: 'address',
                type: 'address',
              },
              { name: 'value', internalType: 'uint16', type: 'uint16' },
            ],
          },
          {
            name: 'subFeeReceivers',
            internalType: 'struct IGildiExchange.Receiver[]',
            type: 'tuple[]',
            components: [
              {
                name: 'receiverAddress',
                internalType: 'address',
                type: 'address',
              },
              {
                name: 'payoutCurrency',
                internalType: 'address',
                type: 'address',
              },
              { name: 'value', internalType: 'uint16', type: 'uint16' },
            ],
          },
        ],
      },
    ],
    name: 'setFees',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      {
        name: '_marketplaceCurrency',
        internalType: 'address',
        type: 'address',
      },
    ],
    name: 'setMarketplaceCurrency',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      {
        name: '_maxBuyPerTransaction',
        internalType: 'uint256',
        type: 'uint256',
      },
    ],
    name: 'setMaxBuyPerTransaction',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      { name: '_releaseId', internalType: 'uint256', type: 'uint256' },
      { name: '_active', internalType: 'bool', type: 'bool' },
    ],
    name: 'setReleaseActive',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      { name: '_releaseId', internalType: 'uint256', type: 'uint256' },
      {
        name: '_additionalFees',
        internalType: 'struct IGildiExchange.FeeDistribution[]',
        type: 'tuple[]',
        components: [
          {
            name: 'feeReceiver',
            internalType: 'struct IGildiExchange.Receiver',
            type: 'tuple',
            components: [
              {
                name: 'receiverAddress',
                internalType: 'address',
                type: 'address',
              },
              {
                name: 'payoutCurrency',
                internalType: 'address',
                type: 'address',
              },
              { name: 'value', internalType: 'uint16', type: 'uint16' },
            ],
          },
          {
            name: 'subFeeReceivers',
            internalType: 'struct IGildiExchange.Receiver[]',
            type: 'tuple[]',
            components: [
              {
                name: 'receiverAddress',
                internalType: 'address',
                type: 'address',
              },
              {
                name: 'payoutCurrency',
                internalType: 'address',
                type: 'address',
              },
              { name: 'value', internalType: 'uint16', type: 'uint16' },
            ],
          },
        ],
      },
    ],
    name: 'setReleaseFees',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      {
        name: '_gildiPriceOracle',
        internalType: 'contract IGildiPriceOracle',
        type: 'address',
      },
      { name: '_askDecimals', internalType: 'uint8', type: 'uint8' },
      {
        name: '_orderBook',
        internalType: 'contract IGildiExchangeOrderBook',
        type: 'address',
      },
      {
        name: '_fundManager',
        internalType: 'contract IGildiExchangeFundManager',
        type: 'address',
      },
      {
        name: '_paymentProcessor',
        internalType: 'contract IGildiExchangePaymentProcessor',
        type: 'address',
      },
      {
        name: '_paymentAggregator',
        internalType: 'contract IGildiExchangePaymentAggregator',
        type: 'address',
      },
    ],
    name: 'setup',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [{ name: 'interfaceId', internalType: 'bytes4', type: 'bytes4' }],
    name: 'supportsInterface',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [
      { name: '_from', internalType: 'address', type: 'address' },
      { name: '_to', internalType: 'address', type: 'address' },
      { name: '_value', internalType: 'uint256', type: 'uint256' },
      { name: '_amountCurrency', internalType: 'address', type: 'address' },
    ],
    name: 'transferTokenInContext',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      { name: '_from', internalType: 'address', type: 'address' },
      { name: '_value', internalType: 'uint256', type: 'uint256' },
      { name: '_amountCurrency', internalType: 'address', type: 'address' },
    ],
    name: 'tryBurnTokenInContext',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      { name: '_releaseId', internalType: 'uint256', type: 'uint256' },
      { name: '_batchSize', internalType: 'uint256', type: 'uint256' },
    ],
    name: 'unlistAllListings',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [],
    name: 'unpause',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  { type: 'receive', stateMutability: 'payable' },
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Faucet
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const faucetAbi = [
  { type: 'constructor', inputs: [], stateMutability: 'nonpayable' },
  { type: 'error', inputs: [], name: 'BadRequest' },
  { type: 'error', inputs: [], name: 'ContractNotMinter' },
  { type: 'error', inputs: [], name: 'InvalidInitialization' },
  { type: 'error', inputs: [], name: 'MintCooldownNotExpired' },
  { type: 'error', inputs: [], name: 'NotInitializing' },
  {
    type: 'error',
    inputs: [{ name: 'owner', internalType: 'address', type: 'address' }],
    name: 'OwnableInvalidOwner',
  },
  {
    type: 'error',
    inputs: [{ name: 'account', internalType: 'address', type: 'address' }],
    name: 'OwnableUnauthorizedAccount',
  },
  { type: 'error', inputs: [], name: 'ReceiveCooldownNotExpired' },
  { type: 'error', inputs: [], name: 'ReentrancyGuardReentrantCall' },
  { type: 'error', inputs: [], name: 'TokenNotFaucetToken' },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'token',
        internalType: 'address',
        type: 'address',
        indexed: false,
      },
      {
        name: 'receiver',
        internalType: 'address',
        type: 'address',
        indexed: false,
      },
      {
        name: 'amount',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false,
      },
    ],
    name: 'FaucetSent',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'token',
        internalType: 'address',
        type: 'address',
        indexed: false,
      },
    ],
    name: 'FaucetTokenRemoved',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'token',
        internalType: 'address',
        type: 'address',
        indexed: false,
      },
      {
        name: 'baseAmount',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false,
      },
    ],
    name: 'FaucetTokenSet',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'version',
        internalType: 'uint64',
        type: 'uint64',
        indexed: false,
      },
    ],
    name: 'Initialized',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'cooldown',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false,
      },
    ],
    name: 'MintCooldownSet',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'previousOwner',
        internalType: 'address',
        type: 'address',
        indexed: true,
      },
      {
        name: 'newOwner',
        internalType: 'address',
        type: 'address',
        indexed: true,
      },
    ],
    name: 'OwnershipTransferred',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'cooldown',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false,
      },
    ],
    name: 'ReceiveCooldownSet',
  },
  {
    type: 'function',
    inputs: [
      { name: '_tokenAddress', internalType: 'address', type: 'address' },
    ],
    name: 'getFaucetTokenBaseAmount',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'getFaucetTokenBaseAmounts',
    outputs: [
      { name: 'tokenAddresses', internalType: 'address[]', type: 'address[]' },
      { name: 'tokenAmounts', internalType: 'uint256[]', type: 'uint256[]' },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'getFaucetTokens',
    outputs: [{ name: '', internalType: 'address[]', type: 'address[]' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [{ name: '_token', internalType: 'address', type: 'address' }],
    name: 'getIsFaucetToken',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [
      { name: 'user', internalType: 'address', type: 'address' },
      { name: 'token', internalType: 'address', type: 'address' },
    ],
    name: 'getLastMinted',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [
      { name: 'user', internalType: 'address', type: 'address' },
      { name: 'token', internalType: 'address', type: 'address' },
    ],
    name: 'getLastReceived',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [
      { name: '_tokenAddress', internalType: 'address', type: 'address' },
      { name: '_caller', internalType: 'address', type: 'address' },
      { name: '_receiver', internalType: 'address', type: 'address' },
    ],
    name: 'getNextMintTimestamp',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [
      { name: '_initialOwner', internalType: 'address', type: 'address' },
      { name: '_mintCooldown', internalType: 'uint256', type: 'uint256' },
      { name: '_receiveCooldown', internalType: 'uint256', type: 'uint256' },
    ],
    name: 'initialize',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [],
    name: 'owner',
    outputs: [{ name: '', internalType: 'address', type: 'address' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [{ name: '_token', internalType: 'address', type: 'address' }],
    name: 'removeFaucetToken',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [],
    name: 'renounceOwnership',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [{ name: '_receiver', internalType: 'address', type: 'address' }],
    name: 'requestAllTokens',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      { name: '_tokenAddress', internalType: 'address', type: 'address' },
      { name: '_receiver', internalType: 'address', type: 'address' },
      { name: '_mintAmount', internalType: 'uint256', type: 'uint256' },
    ],
    name: 'requestToken',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      { name: '_tokenAddress', internalType: 'address[]', type: 'address[]' },
      { name: '_receiver', internalType: 'address', type: 'address' },
      { name: '_mintAmount', internalType: 'uint256[]', type: 'uint256[]' },
    ],
    name: 'requestTokens',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      { name: '_tokenAddress', internalType: 'address', type: 'address' },
      { name: '_baseAmount', internalType: 'uint256', type: 'uint256' },
    ],
    name: 'setFaucetToken',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [{ name: '_cooldown', internalType: 'uint256', type: 'uint256' }],
    name: 'setMintCooldown',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [{ name: '_cooldown', internalType: 'uint256', type: 'uint256' }],
    name: 'setReceiveCooldown',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [{ name: 'newOwner', internalType: 'address', type: 'address' }],
    name: 'transferOwnership',
    outputs: [],
    stateMutability: 'nonpayable',
  },
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Manager
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const managerAbi = [
  { type: 'constructor', inputs: [], stateMutability: 'nonpayable' },
  { type: 'error', inputs: [], name: 'AccessControlBadConfirmation' },
  {
    type: 'error',
    inputs: [
      { name: 'account', internalType: 'address', type: 'address' },
      { name: 'neededRole', internalType: 'bytes32', type: 'bytes32' },
    ],
    name: 'AccessControlUnauthorizedAccount',
  },
  {
    type: 'error',
    inputs: [
      { name: 'account', internalType: 'address', type: 'address' },
      { name: 'roles', internalType: 'bytes32[]', type: 'bytes32[]' },
    ],
    name: 'AccessControlUnauthorizedAccountAny',
  },
  { type: 'error', inputs: [], name: 'AddressZeroNotAllowed' },
  { type: 'error', inputs: [], name: 'AmountMustBeGreaterThanZero' },
  {
    type: 'error',
    inputs: [
      { name: 'tokenId', internalType: 'uint256', type: 'uint256' },
      { name: 'account', internalType: 'address', type: 'address' },
    ],
    name: 'InsufficientAvailableBalance',
  },
  {
    type: 'error',
    inputs: [
      { name: 'unassignedShares', internalType: 'uint256', type: 'uint256' },
      { name: 'requiredAmount', internalType: 'uint256', type: 'uint256' },
    ],
    name: 'InsufficientUnassignedShares',
  },
  {
    type: 'error',
    inputs: [
      { name: 'batchSizeMin', internalType: 'uint256', type: 'uint256' },
      { name: 'batchSizeMax', internalType: 'uint256', type: 'uint256' },
    ],
    name: 'InvalidBatchSize',
  },
  { type: 'error', inputs: [], name: 'InvalidInitialization' },
  {
    type: 'error',
    inputs: [
      { name: 'expectedState', internalType: 'bool', type: 'bool' },
      { name: 'actualState', internalType: 'bool', type: 'bool' },
    ],
    name: 'InvalidLockState',
  },
  { type: 'error', inputs: [], name: 'NotFullyAssignedShares' },
  { type: 'error', inputs: [], name: 'NotInitializing' },
  { type: 'error', inputs: [], name: 'ReentrancyGuardReentrantCall' },
  {
    type: 'error',
    inputs: [{ name: 'tokenId', internalType: 'uint256', type: 'uint256' }],
    name: 'ReleaseAlreadyExists',
  },
  {
    type: 'error',
    inputs: [{ name: 'tokenId', internalType: 'uint256', type: 'uint256' }],
    name: 'ReleaseDoesNotExist',
  },
  {
    type: 'error',
    inputs: [{ name: 'tokenId', internalType: 'uint256', type: 'uint256' }],
    name: 'ReleaseIsDeleting',
  },
  {
    type: 'error',
    inputs: [{ name: 'tokenId', internalType: 'uint256', type: 'uint256' }],
    name: 'ReleaseTokenAlreadyExists',
  },
  { type: 'error', inputs: [], name: 'SharesMustNotBeEmpty' },
  {
    type: 'error',
    inputs: [{ name: 'maxShares', internalType: 'uint256', type: 'uint256' }],
    name: 'TooManyShares',
  },
  {
    type: 'error',
    inputs: [
      { name: 'expectedState', internalType: 'bool', type: 'bool' },
      { name: 'actualState', internalType: 'bool', type: 'bool' },
    ],
    name: 'WrongInitialSaleState',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'releaseId',
        internalType: 'uint256',
        type: 'uint256',
        indexed: true,
      },
    ],
    name: 'InitialSaleEnded',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'releaseId',
        internalType: 'uint256',
        type: 'uint256',
        indexed: true,
      },
    ],
    name: 'InitialSaleStarted',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'version',
        internalType: 'uint64',
        type: 'uint64',
        indexed: false,
      },
    ],
    name: 'Initialized',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'releaseId',
        internalType: 'uint256',
        type: 'uint256',
        indexed: true,
      },
      {
        name: 'deletedShares',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false,
      },
      {
        name: 'remainingOwners',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false,
      },
    ],
    name: 'ReleaseBatchDeleted',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'releaseId',
        internalType: 'uint256',
        type: 'uint256',
        indexed: true,
      },
      {
        name: 'amount',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false,
      },
    ],
    name: 'ReleaseCreated',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'releaseId',
        internalType: 'uint256',
        type: 'uint256',
        indexed: true,
      },
    ],
    name: 'ReleaseDeleted',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'releaseId',
        internalType: 'uint256',
        type: 'uint256',
        indexed: true,
      },
    ],
    name: 'ReleaseMarkedForDeletion',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'releaseId',
        internalType: 'uint256',
        type: 'uint256',
        indexed: true,
      },
    ],
    name: 'ReleaseUnlocked',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      { name: 'role', internalType: 'bytes32', type: 'bytes32', indexed: true },
      {
        name: 'previousAdminRole',
        internalType: 'bytes32',
        type: 'bytes32',
        indexed: true,
      },
      {
        name: 'newAdminRole',
        internalType: 'bytes32',
        type: 'bytes32',
        indexed: true,
      },
    ],
    name: 'RoleAdminChanged',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      { name: 'role', internalType: 'bytes32', type: 'bytes32', indexed: true },
      {
        name: 'account',
        internalType: 'address',
        type: 'address',
        indexed: true,
      },
      {
        name: 'sender',
        internalType: 'address',
        type: 'address',
        indexed: true,
      },
    ],
    name: 'RoleGranted',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      { name: 'role', internalType: 'bytes32', type: 'bytes32', indexed: true },
      {
        name: 'account',
        internalType: 'address',
        type: 'address',
        indexed: true,
      },
      {
        name: 'sender',
        internalType: 'address',
        type: 'address',
        indexed: true,
      },
    ],
    name: 'RoleRevoked',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'releaseId',
        internalType: 'uint256',
        type: 'uint256',
        indexed: true,
      },
      { name: 'user', internalType: 'address', type: 'address', indexed: true },
      {
        name: 'shares',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false,
      },
    ],
    name: 'ShareAssigned',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'releaseId',
        internalType: 'uint256',
        type: 'uint256',
        indexed: true,
      },
      {
        name: 'totalShares',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false,
      },
    ],
    name: 'SharesAssigned',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'tokenId',
        internalType: 'uint256',
        type: 'uint256',
        indexed: true,
      },
      {
        name: 'account',
        internalType: 'address',
        type: 'address',
        indexed: true,
      },
      {
        name: 'amount',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false,
      },
    ],
    name: 'TokenDeposited',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'tokenId',
        internalType: 'uint256',
        type: 'uint256',
        indexed: true,
      },
      {
        name: 'account',
        internalType: 'address',
        type: 'address',
        indexed: true,
      },
      {
        name: 'amount',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false,
      },
    ],
    name: 'TokenLocked',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'tokenId',
        internalType: 'uint256',
        type: 'uint256',
        indexed: true,
      },
      { name: 'from', internalType: 'address', type: 'address', indexed: true },
      { name: 'to', internalType: 'address', type: 'address', indexed: true },
      {
        name: 'amount',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false,
      },
    ],
    name: 'TokenTransferred',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'tokenId',
        internalType: 'uint256',
        type: 'uint256',
        indexed: true,
      },
      {
        name: 'account',
        internalType: 'address',
        type: 'address',
        indexed: true,
      },
      {
        name: 'amount',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false,
      },
    ],
    name: 'TokenUnlocked',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'tokenId',
        internalType: 'uint256',
        type: 'uint256',
        indexed: true,
      },
      {
        name: 'account',
        internalType: 'address',
        type: 'address',
        indexed: true,
      },
      {
        name: 'amount',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false,
      },
    ],
    name: 'TokenWithdrawn',
  },
  {
    type: 'function',
    inputs: [],
    name: 'ADMIN_ROLE',
    outputs: [{ name: '', internalType: 'bytes32', type: 'bytes32' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'DEFAULT_ADMIN_ROLE',
    outputs: [{ name: '', internalType: 'bytes32', type: 'bytes32' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'MARKETPLACE_ROLE',
    outputs: [{ name: '', internalType: 'bytes32', type: 'bytes32' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'RELEASE_MANAGER_ROLE',
    outputs: [{ name: '', internalType: 'bytes32', type: 'bytes32' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [
      { name: '_releaseId', internalType: 'uint256', type: 'uint256' },
      {
        name: '_sharesBatch',
        internalType: 'struct IGildiManager.UserShare[]',
        type: 'tuple[]',
        components: [
          { name: 'user', internalType: 'address', type: 'address' },
          { name: 'shares', internalType: 'uint256', type: 'uint256' },
        ],
      },
    ],
    name: 'assignShares',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      { name: '_tokenId', internalType: 'uint256', type: 'uint256' },
      { name: '_account', internalType: 'address', type: 'address' },
    ],
    name: 'balanceOf',
    outputs: [
      {
        name: '',
        internalType: 'struct IGildiManager.TokenBalance',
        type: 'tuple',
        components: [
          { name: 'tokenId', internalType: 'uint256', type: 'uint256' },
          { name: 'amount', internalType: 'uint256', type: 'uint256' },
          { name: 'lockedAmount', internalType: 'uint256', type: 'uint256' },
        ],
      },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [{ name: '_account', internalType: 'address', type: 'address' }],
    name: 'balanceOf',
    outputs: [
      {
        name: '',
        internalType: 'struct IGildiManager.TokenBalance[]',
        type: 'tuple[]',
        components: [
          { name: 'tokenId', internalType: 'uint256', type: 'uint256' },
          { name: 'amount', internalType: 'uint256', type: 'uint256' },
          { name: 'lockedAmount', internalType: 'uint256', type: 'uint256' },
        ],
      },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [
      { name: '_releaseId', internalType: 'uint256', type: 'uint256' },
      { name: '_batchSizeOwners', internalType: 'uint256', type: 'uint256' },
    ],
    name: 'batchDeleteRelease',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [{ name: '_releaseId', internalType: 'uint256', type: 'uint256' }],
    name: 'cancelInitialSale',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      { name: '_tokenId', internalType: 'uint256', type: 'uint256' },
      { name: '_amount', internalType: 'uint256', type: 'uint256' },
      {
        name: '_ownershipTrackingTimePeriod',
        internalType: 'uint256',
        type: 'uint256',
      },
    ],
    name: 'createNewRelease',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      { name: '_tokenId', internalType: 'uint256', type: 'uint256' },
      { name: '_account', internalType: 'address', type: 'address' },
      { name: '_amount', internalType: 'uint256', type: 'uint256' },
    ],
    name: 'deposit',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [{ name: '_releaseId', internalType: 'uint256', type: 'uint256' }],
    name: 'endInitialSale',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      { name: '_tokenId', internalType: 'uint256', type: 'uint256' },
      { name: '_start', internalType: 'uint256', type: 'uint256' },
      { name: '_end', internalType: 'uint256', type: 'uint256' },
      { name: '_cursor', internalType: 'uint256', type: 'uint256' },
      { name: '_limit', internalType: 'uint256', type: 'uint256' },
    ],
    name: 'fetchSharesInPeriod',
    outputs: [
      {
        name: '',
        internalType: 'struct IGildiManager.SharesReport',
        type: 'tuple',
        components: [
          { name: 'tokenId', internalType: 'uint256', type: 'uint256' },
          { name: 'start', internalType: 'uint256', type: 'uint256' },
          { name: 'end', internalType: 'uint256', type: 'uint256' },
          {
            name: 'totalNumberOfShares',
            internalType: 'uint256',
            type: 'uint256',
          },
          {
            name: 'userShares',
            internalType: 'struct IGildiManager.UserShare[]',
            type: 'tuple[]',
            components: [
              { name: 'user', internalType: 'address', type: 'address' },
              { name: 'shares', internalType: 'uint256', type: 'uint256' },
            ],
          },
          { name: 'hasMore', internalType: 'bool', type: 'bool' },
          { name: 'nextCursor', internalType: 'uint256', type: 'uint256' },
        ],
      },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'getAllReleaseIds',
    outputs: [{ name: '', internalType: 'uint256[]', type: 'uint256[]' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [
      { name: '_tokenId', internalType: 'uint256', type: 'uint256' },
      { name: '_account', internalType: 'address', type: 'address' },
    ],
    name: 'getAvailableBalance',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [{ name: '_releaseId', internalType: 'uint256', type: 'uint256' }],
    name: 'getReleaseById',
    outputs: [
      {
        name: '',
        internalType: 'struct IGildiManager.RWARelease',
        type: 'tuple',
        components: [
          { name: 'tokenId', internalType: 'uint256', type: 'uint256' },
          { name: 'locked', internalType: 'bool', type: 'bool' },
          { name: 'unlockedAt', internalType: 'uint256', type: 'uint256' },
          { name: 'inInitialSale', internalType: 'bool', type: 'bool' },
          { name: 'totalShares', internalType: 'uint256', type: 'uint256' },
          {
            name: 'unassignedShares',
            internalType: 'uint256',
            type: 'uint256',
          },
          { name: 'burnedShares', internalType: 'uint256', type: 'uint256' },
          { name: 'deleting', internalType: 'bool', type: 'bool' },
          { name: 'deletedShares', internalType: 'uint256', type: 'uint256' },
          { name: 'createdAt', internalType: 'uint256', type: 'uint256' },
        ],
      },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [{ name: 'role', internalType: 'bytes32', type: 'bytes32' }],
    name: 'getRoleAdmin',
    outputs: [{ name: '', internalType: 'bytes32', type: 'bytes32' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'gildiToken',
    outputs: [
      { name: '', internalType: 'contract IGildiToken', type: 'address' },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [
      { name: 'role', internalType: 'bytes32', type: 'bytes32' },
      { name: 'account', internalType: 'address', type: 'address' },
    ],
    name: 'grantRole',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      { name: 'role', internalType: 'bytes32', type: 'bytes32' },
      { name: 'account', internalType: 'address', type: 'address' },
    ],
    name: 'hasRole',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [
      { name: '_defaultAdmin', internalType: 'address', type: 'address' },
      { name: '_initialAdmin', internalType: 'address', type: 'address' },
      {
        name: '_initialReleaseManager',
        internalType: 'address',
        type: 'address',
      },
      {
        name: '_rwaToken',
        internalType: 'contract IGildiToken',
        type: 'address',
      },
    ],
    name: 'initialize',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [{ name: '_releaseId', internalType: 'uint256', type: 'uint256' }],
    name: 'isFullyAssigned',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [{ name: '_releaseId', internalType: 'uint256', type: 'uint256' }],
    name: 'isInInitialSale',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [{ name: '_releaseId', internalType: 'uint256', type: 'uint256' }],
    name: 'isLocked',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [
      { name: '_account', internalType: 'address', type: 'address' },
      { name: '_tokenId', internalType: 'uint256', type: 'uint256' },
      { name: '_amountToLock', internalType: 'uint256', type: 'uint256' },
    ],
    name: 'lockTokens',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      { name: '', internalType: 'address', type: 'address' },
      { name: '', internalType: 'address', type: 'address' },
      { name: '', internalType: 'uint256[]', type: 'uint256[]' },
      { name: '', internalType: 'uint256[]', type: 'uint256[]' },
      { name: '', internalType: 'bytes', type: 'bytes' },
    ],
    name: 'onERC1155BatchReceived',
    outputs: [{ name: '', internalType: 'bytes4', type: 'bytes4' }],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      { name: '', internalType: 'address', type: 'address' },
      { name: '', internalType: 'address', type: 'address' },
      { name: '', internalType: 'uint256', type: 'uint256' },
      { name: '', internalType: 'uint256', type: 'uint256' },
      { name: '', internalType: 'bytes', type: 'bytes' },
    ],
    name: 'onERC1155Received',
    outputs: [{ name: '', internalType: 'bytes4', type: 'bytes4' }],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [{ name: '_tokenId', internalType: 'uint256', type: 'uint256' }],
    name: 'ownersOfToken',
    outputs: [{ name: '', internalType: 'address[]', type: 'address[]' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [{ name: '_releaseId', internalType: 'uint256', type: 'uint256' }],
    name: 'releaseExists',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    name: 'releaseOwnershipStorages',
    outputs: [
      {
        name: '',
        internalType: 'contract GildiManagerOwnershipStorage',
        type: 'address',
      },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [
      { name: 'role', internalType: 'bytes32', type: 'bytes32' },
      { name: 'callerConfirmation', internalType: 'address', type: 'address' },
    ],
    name: 'renounceRole',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      { name: 'role', internalType: 'bytes32', type: 'bytes32' },
      { name: 'account', internalType: 'address', type: 'address' },
    ],
    name: 'revokeRole',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    name: 'rwaReleaseIds',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    name: 'rwaReleases',
    outputs: [
      { name: 'tokenId', internalType: 'uint256', type: 'uint256' },
      { name: 'locked', internalType: 'bool', type: 'bool' },
      { name: 'unlockedAt', internalType: 'uint256', type: 'uint256' },
      { name: 'inInitialSale', internalType: 'bool', type: 'bool' },
      { name: 'totalShares', internalType: 'uint256', type: 'uint256' },
      { name: 'unassignedShares', internalType: 'uint256', type: 'uint256' },
      { name: 'burnedShares', internalType: 'uint256', type: 'uint256' },
      { name: 'deleting', internalType: 'bool', type: 'bool' },
      { name: 'deletedShares', internalType: 'uint256', type: 'uint256' },
      { name: 'createdAt', internalType: 'uint256', type: 'uint256' },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [{ name: '_releaseId', internalType: 'uint256', type: 'uint256' }],
    name: 'startInitialSale',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [{ name: '_interfaceId', internalType: 'bytes4', type: 'bytes4' }],
    name: 'supportsInterface',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [
      { name: '_tokenId', internalType: 'uint256', type: 'uint256' },
      { name: '_from', internalType: 'address', type: 'address' },
      { name: '_to', internalType: 'address', type: 'address' },
      { name: '_amount', internalType: 'uint256', type: 'uint256' },
    ],
    name: 'transferOwnership',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      { name: '_tokenId', internalType: 'uint256', type: 'uint256' },
      { name: '_from', internalType: 'address', type: 'address' },
      { name: '_to', internalType: 'address', type: 'address' },
      { name: '_amount', internalType: 'uint256', type: 'uint256' },
    ],
    name: 'transferOwnershipInitialSale',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [{ name: '_releaseId', internalType: 'uint256', type: 'uint256' }],
    name: 'unlockRelease',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      { name: '_account', internalType: 'address', type: 'address' },
      { name: '_tokenId', internalType: 'uint256', type: 'uint256' },
      { name: '_amountToUnlock', internalType: 'uint256', type: 'uint256' },
    ],
    name: 'unlockTokens',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      { name: '_tokenId', internalType: 'uint256', type: 'uint256' },
      { name: '_account', internalType: 'address', type: 'address' },
      { name: '_amount', internalType: 'uint256', type: 'uint256' },
    ],
    name: 'withdraw',
    outputs: [],
    stateMutability: 'nonpayable',
  },
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// OrderBook
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const orderBookAbi = [
  { type: 'constructor', inputs: [], stateMutability: 'nonpayable' },
  { type: 'error', inputs: [], name: 'InvalidInitialization' },
  {
    type: 'error',
    inputs: [{ name: 'listingId', internalType: 'uint256', type: 'uint256' }],
    name: 'ListingError',
  },
  { type: 'error', inputs: [], name: 'NotAllowed' },
  { type: 'error', inputs: [], name: 'NotGildiExchange' },
  { type: 'error', inputs: [], name: 'NotInitializing' },
  { type: 'error', inputs: [], name: 'ParamError' },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'version',
        internalType: 'uint64',
        type: 'uint64',
        indexed: false,
      },
    ],
    name: 'Initialized',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'listingId',
        internalType: 'uint256',
        type: 'uint256',
        indexed: true,
      },
      {
        name: 'releaseId',
        internalType: 'uint256',
        type: 'uint256',
        indexed: true,
      },
      {
        name: 'seller',
        internalType: 'address',
        type: 'address',
        indexed: true,
      },
      {
        name: 'price',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false,
      },
      {
        name: 'quantity',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false,
      },
    ],
    name: 'Listed',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'listingId',
        internalType: 'uint256',
        type: 'uint256',
        indexed: true,
      },
      {
        name: 'releaseId',
        internalType: 'uint256',
        type: 'uint256',
        indexed: true,
      },
      {
        name: 'seller',
        internalType: 'address',
        type: 'address',
        indexed: true,
      },
      {
        name: 'price',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false,
      },
      {
        name: 'quantity',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false,
      },
    ],
    name: 'Modified',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'listingId',
        internalType: 'uint256',
        type: 'uint256',
        indexed: true,
      },
      {
        name: 'releaseId',
        internalType: 'uint256',
        type: 'uint256',
        indexed: true,
      },
      {
        name: 'seller',
        internalType: 'address',
        type: 'address',
        indexed: true,
      },
      {
        name: 'quantity',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false,
      },
    ],
    name: 'Unlisted',
  },
  { type: 'fallback', stateMutability: 'payable' },
  {
    type: 'function',
    inputs: [
      { name: '_releaseId', internalType: 'uint256', type: 'uint256' },
      { name: '_user', internalType: 'address', type: 'address' },
    ],
    name: 'getAvailableBuyQuantity',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [{ name: '_releaseId', internalType: 'uint256', type: 'uint256' }],
    name: 'getHeadListingId',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [{ name: '_listingId', internalType: 'uint256', type: 'uint256' }],
    name: 'getListing',
    outputs: [
      {
        name: '',
        internalType: 'struct IGildiExchangeOrderBook.Listing',
        type: 'tuple',
        components: [
          { name: 'id', internalType: 'uint256', type: 'uint256' },
          { name: 'releaseId', internalType: 'uint256', type: 'uint256' },
          { name: 'seller', internalType: 'address', type: 'address' },
          { name: 'pricePerItem', internalType: 'uint256', type: 'uint256' },
          { name: 'payoutCurrency', internalType: 'address', type: 'address' },
          { name: 'quantity', internalType: 'uint256', type: 'uint256' },
          { name: 'slippageBps', internalType: 'uint16', type: 'uint16' },
          { name: 'createdAt', internalType: 'uint256', type: 'uint256' },
          { name: 'modifiedAt', internalType: 'uint256', type: 'uint256' },
          { name: 'nextListingId', internalType: 'uint256', type: 'uint256' },
          { name: 'prevListingId', internalType: 'uint256', type: 'uint256' },
          { name: 'fundsReceiver', internalType: 'address', type: 'address' },
        ],
      },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [{ name: '_seller', internalType: 'address', type: 'address' }],
    name: 'getListingsOfSeller',
    outputs: [
      {
        name: '',
        internalType: 'struct IGildiExchangeOrderBook.Listing[]',
        type: 'tuple[]',
        components: [
          { name: 'id', internalType: 'uint256', type: 'uint256' },
          { name: 'releaseId', internalType: 'uint256', type: 'uint256' },
          { name: 'seller', internalType: 'address', type: 'address' },
          { name: 'pricePerItem', internalType: 'uint256', type: 'uint256' },
          { name: 'payoutCurrency', internalType: 'address', type: 'address' },
          { name: 'quantity', internalType: 'uint256', type: 'uint256' },
          { name: 'slippageBps', internalType: 'uint16', type: 'uint16' },
          { name: 'createdAt', internalType: 'uint256', type: 'uint256' },
          { name: 'modifiedAt', internalType: 'uint256', type: 'uint256' },
          { name: 'nextListingId', internalType: 'uint256', type: 'uint256' },
          { name: 'prevListingId', internalType: 'uint256', type: 'uint256' },
          { name: 'fundsReceiver', internalType: 'address', type: 'address' },
        ],
      },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [{ name: '_listingId', internalType: 'uint256', type: 'uint256' }],
    name: 'getNextListingId',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [
      { name: '_releaseId', internalType: 'uint256', type: 'uint256' },
      { name: '_cursor', internalType: 'uint256', type: 'uint256' },
      { name: '_limit', internalType: 'uint256', type: 'uint256' },
    ],
    name: 'getOrderedListings',
    outputs: [
      {
        name: 'orderedListings',
        internalType: 'struct IGildiExchangeOrderBook.Listing[]',
        type: 'tuple[]',
        components: [
          { name: 'id', internalType: 'uint256', type: 'uint256' },
          { name: 'releaseId', internalType: 'uint256', type: 'uint256' },
          { name: 'seller', internalType: 'address', type: 'address' },
          { name: 'pricePerItem', internalType: 'uint256', type: 'uint256' },
          { name: 'payoutCurrency', internalType: 'address', type: 'address' },
          { name: 'quantity', internalType: 'uint256', type: 'uint256' },
          { name: 'slippageBps', internalType: 'uint16', type: 'uint16' },
          { name: 'createdAt', internalType: 'uint256', type: 'uint256' },
          { name: 'modifiedAt', internalType: 'uint256', type: 'uint256' },
          { name: 'nextListingId', internalType: 'uint256', type: 'uint256' },
          { name: 'prevListingId', internalType: 'uint256', type: 'uint256' },
          { name: 'fundsReceiver', internalType: 'address', type: 'address' },
        ],
      },
      { name: 'cursor', internalType: 'uint256', type: 'uint256' },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'gildiExchange',
    outputs: [
      { name: '', internalType: 'contract IGildiExchange', type: 'address' },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'gildiManager',
    outputs: [
      { name: '', internalType: 'contract IGildiManager', type: 'address' },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [
      { name: '_releaseId', internalType: 'uint256', type: 'uint256' },
      { name: '_seller', internalType: 'address', type: 'address' },
      { name: '_pricePerItem', internalType: 'uint256', type: 'uint256' },
      { name: '_quantity', internalType: 'uint256', type: 'uint256' },
      { name: '_payoutCurrency', internalType: 'address', type: 'address' },
      { name: '_fundsReceiver', internalType: 'address', type: 'address' },
      { name: '_slippageBps', internalType: 'uint16', type: 'uint16' },
    ],
    name: 'handleCreateListing',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      { name: '_listingId', internalType: 'uint256', type: 'uint256' },
      { name: '_quantityToBuy', internalType: 'uint256', type: 'uint256' },
    ],
    name: 'handleDecreaseListingQuantity',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      { name: '_listingId', internalType: 'uint256', type: 'uint256' },
      { name: '_pricePerItem', internalType: 'uint256', type: 'uint256' },
      { name: '_quantity', internalType: 'uint256', type: 'uint256' },
      { name: '_payoutCurrency', internalType: 'address', type: 'address' },
      { name: '_fundsReceiver', internalType: 'address', type: 'address' },
      { name: '_slippageBps', internalType: 'uint16', type: 'uint16' },
    ],
    name: 'handleModifyListing',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [{ name: '_listingId', internalType: 'uint256', type: 'uint256' }],
    name: 'handleRemoveListing',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      { name: '_releaseId', internalType: 'uint256', type: 'uint256' },
      { name: '_batchSize', internalType: 'uint256', type: 'uint256' },
    ],
    name: 'handleUnlistReleaseListings',
    outputs: [
      { name: 'processedListings', internalType: 'uint256', type: 'uint256' },
    ],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      { name: '_gildiExchange', internalType: 'address', type: 'address' },
      { name: '_gildiManager', internalType: 'address', type: 'address' },
    ],
    name: 'initialize',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [{ name: '_releaseId', internalType: 'uint256', type: 'uint256' }],
    name: 'listedQuantities',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [
      { name: '_releaseId', internalType: 'uint256', type: 'uint256' },
      { name: '_buyer', internalType: 'address', type: 'address' },
      { name: '_amountToBuy', internalType: 'uint256', type: 'uint256' },
    ],
    name: 'previewPurchase',
    outputs: [
      {
        name: '',
        internalType: 'struct IGildiExchangeOrderBook.PurchasePreview',
        type: 'tuple',
        components: [
          {
            name: 'totalQuantityAvailable',
            internalType: 'uint256',
            type: 'uint256',
          },
          {
            name: 'totalPriceInCurrency',
            internalType: 'uint256',
            type: 'uint256',
          },
          { name: 'currency', internalType: 'address', type: 'address' },
          { name: 'totalPriceUsd', internalType: 'uint256', type: 'uint256' },
        ],
      },
    ],
    stateMutability: 'view',
  },
  { type: 'receive', stateMutability: 'payable' },
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ShareToken
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const shareTokenAbi = [
  { type: 'constructor', inputs: [], stateMutability: 'nonpayable' },
  { type: 'error', inputs: [], name: 'AccessControlBadConfirmation' },
  {
    type: 'error',
    inputs: [
      { name: 'account', internalType: 'address', type: 'address' },
      { name: 'neededRole', internalType: 'bytes32', type: 'bytes32' },
    ],
    name: 'AccessControlUnauthorizedAccount',
  },
  {
    type: 'error',
    inputs: [
      { name: 'sender', internalType: 'address', type: 'address' },
      { name: 'balance', internalType: 'uint256', type: 'uint256' },
      { name: 'needed', internalType: 'uint256', type: 'uint256' },
      { name: 'tokenId', internalType: 'uint256', type: 'uint256' },
    ],
    name: 'ERC1155InsufficientBalance',
  },
  {
    type: 'error',
    inputs: [{ name: 'approver', internalType: 'address', type: 'address' }],
    name: 'ERC1155InvalidApprover',
  },
  {
    type: 'error',
    inputs: [
      { name: 'idsLength', internalType: 'uint256', type: 'uint256' },
      { name: 'valuesLength', internalType: 'uint256', type: 'uint256' },
    ],
    name: 'ERC1155InvalidArrayLength',
  },
  {
    type: 'error',
    inputs: [{ name: 'operator', internalType: 'address', type: 'address' }],
    name: 'ERC1155InvalidOperator',
  },
  {
    type: 'error',
    inputs: [{ name: 'receiver', internalType: 'address', type: 'address' }],
    name: 'ERC1155InvalidReceiver',
  },
  {
    type: 'error',
    inputs: [{ name: 'sender', internalType: 'address', type: 'address' }],
    name: 'ERC1155InvalidSender',
  },
  {
    type: 'error',
    inputs: [
      { name: 'operator', internalType: 'address', type: 'address' },
      { name: 'owner', internalType: 'address', type: 'address' },
    ],
    name: 'ERC1155MissingApprovalForAll',
  },
  { type: 'error', inputs: [], name: 'EnforcedPause' },
  {
    type: 'error',
    inputs: [{ name: 'key', internalType: 'bytes32', type: 'bytes32' }],
    name: 'EnumerableMapNonexistentKey',
  },
  { type: 'error', inputs: [], name: 'ExpectedPause' },
  { type: 'error', inputs: [], name: 'InvalidId' },
  { type: 'error', inputs: [], name: 'InvalidInitialization' },
  { type: 'error', inputs: [], name: 'InvalidMintBatch' },
  { type: 'error', inputs: [], name: 'NotInitializing' },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'account',
        internalType: 'address',
        type: 'address',
        indexed: true,
      },
      {
        name: 'operator',
        internalType: 'address',
        type: 'address',
        indexed: true,
      },
      { name: 'approved', internalType: 'bool', type: 'bool', indexed: false },
    ],
    name: 'ApprovalForAll',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'version',
        internalType: 'uint64',
        type: 'uint64',
        indexed: false,
      },
    ],
    name: 'Initialized',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'newName',
        internalType: 'string',
        type: 'string',
        indexed: false,
      },
    ],
    name: 'NameChanged',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'account',
        internalType: 'address',
        type: 'address',
        indexed: false,
      },
    ],
    name: 'Paused',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      { name: 'role', internalType: 'bytes32', type: 'bytes32', indexed: true },
      {
        name: 'previousAdminRole',
        internalType: 'bytes32',
        type: 'bytes32',
        indexed: true,
      },
      {
        name: 'newAdminRole',
        internalType: 'bytes32',
        type: 'bytes32',
        indexed: true,
      },
    ],
    name: 'RoleAdminChanged',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      { name: 'role', internalType: 'bytes32', type: 'bytes32', indexed: true },
      {
        name: 'account',
        internalType: 'address',
        type: 'address',
        indexed: true,
      },
      {
        name: 'sender',
        internalType: 'address',
        type: 'address',
        indexed: true,
      },
    ],
    name: 'RoleGranted',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      { name: 'role', internalType: 'bytes32', type: 'bytes32', indexed: true },
      {
        name: 'account',
        internalType: 'address',
        type: 'address',
        indexed: true,
      },
      {
        name: 'sender',
        internalType: 'address',
        type: 'address',
        indexed: true,
      },
    ],
    name: 'RoleRevoked',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'newSymbol',
        internalType: 'string',
        type: 'string',
        indexed: false,
      },
    ],
    name: 'SymbolChanged',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      { name: 'replaceId', internalType: 'bool', type: 'bool', indexed: false },
    ],
    name: 'TokenUriReplaceIdChanged',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'operator',
        internalType: 'address',
        type: 'address',
        indexed: true,
      },
      { name: 'from', internalType: 'address', type: 'address', indexed: true },
      { name: 'to', internalType: 'address', type: 'address', indexed: true },
      {
        name: 'ids',
        internalType: 'uint256[]',
        type: 'uint256[]',
        indexed: false,
      },
      {
        name: 'values',
        internalType: 'uint256[]',
        type: 'uint256[]',
        indexed: false,
      },
    ],
    name: 'TransferBatch',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'operator',
        internalType: 'address',
        type: 'address',
        indexed: true,
      },
      { name: 'from', internalType: 'address', type: 'address', indexed: true },
      { name: 'to', internalType: 'address', type: 'address', indexed: true },
      { name: 'id', internalType: 'uint256', type: 'uint256', indexed: false },
      {
        name: 'value',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false,
      },
    ],
    name: 'TransferSingle',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      { name: 'value', internalType: 'string', type: 'string', indexed: false },
      { name: 'id', internalType: 'uint256', type: 'uint256', indexed: true },
    ],
    name: 'URI',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'newURI',
        internalType: 'string',
        type: 'string',
        indexed: false,
      },
    ],
    name: 'URIChanged',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'account',
        internalType: 'address',
        type: 'address',
        indexed: false,
      },
    ],
    name: 'Unpaused',
  },
  {
    type: 'function',
    inputs: [],
    name: 'ADMIN_ROLE',
    outputs: [{ name: '', internalType: 'bytes32', type: 'bytes32' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'DEFAULT_ADMIN_ROLE',
    outputs: [{ name: '', internalType: 'bytes32', type: 'bytes32' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'GILDI_MANAGER_ROLE',
    outputs: [{ name: '', internalType: 'bytes32', type: 'bytes32' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [
      { name: 'account', internalType: 'address', type: 'address' },
      { name: 'id', internalType: 'uint256', type: 'uint256' },
    ],
    name: 'balanceOf',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [
      { name: 'accounts', internalType: 'address[]', type: 'address[]' },
      { name: 'ids', internalType: 'uint256[]', type: 'uint256[]' },
    ],
    name: 'balanceOfBatch',
    outputs: [{ name: '', internalType: 'uint256[]', type: 'uint256[]' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [
      { name: '_account', internalType: 'address', type: 'address' },
      { name: '_id', internalType: 'uint256', type: 'uint256' },
      { name: '_value', internalType: 'uint256', type: 'uint256' },
    ],
    name: 'burn',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [{ name: '_id', internalType: 'uint256', type: 'uint256' }],
    name: 'burnAllById',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      { name: '_account', internalType: 'address', type: 'address' },
      { name: '_ids', internalType: 'uint256[]', type: 'uint256[]' },
      { name: '_values', internalType: 'uint256[]', type: 'uint256[]' },
    ],
    name: 'burnBatch',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [{ name: '_id', internalType: 'uint256', type: 'uint256' }],
    name: 'exists',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [{ name: 'role', internalType: 'bytes32', type: 'bytes32' }],
    name: 'getRoleAdmin',
    outputs: [{ name: '', internalType: 'bytes32', type: 'bytes32' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [
      { name: 'role', internalType: 'bytes32', type: 'bytes32' },
      { name: 'account', internalType: 'address', type: 'address' },
    ],
    name: 'grantRole',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      { name: 'role', internalType: 'bytes32', type: 'bytes32' },
      { name: 'account', internalType: 'address', type: 'address' },
    ],
    name: 'hasRole',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [
      { name: '_defaultAdmin', internalType: 'address', type: 'address' },
      { name: '_initialAdmin', internalType: 'address', type: 'address' },
      { name: '_baseUri', internalType: 'string', type: 'string' },
    ],
    name: 'initialize',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      { name: 'account', internalType: 'address', type: 'address' },
      { name: 'operator', internalType: 'address', type: 'address' },
    ],
    name: 'isApprovedForAll',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [
      { name: '_account', internalType: 'address', type: 'address' },
      { name: '_id', internalType: 'uint256', type: 'uint256' },
      { name: '_amount', internalType: 'uint256', type: 'uint256' },
      { name: '_data', internalType: 'bytes', type: 'bytes' },
    ],
    name: 'mint',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      { name: '_to', internalType: 'address', type: 'address' },
      { name: '_ids', internalType: 'uint256[]', type: 'uint256[]' },
      { name: '_amounts', internalType: 'uint256[]', type: 'uint256[]' },
      { name: '_data', internalType: 'bytes', type: 'bytes' },
    ],
    name: 'mintBatch',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      {
        name: '_mintBatches',
        internalType: 'struct IGildiToken.MintBatch[]',
        type: 'tuple[]',
        components: [
          { name: 'to', internalType: 'address', type: 'address' },
          { name: 'ids', internalType: 'uint256[]', type: 'uint256[]' },
          { name: 'amounts', internalType: 'uint256[]', type: 'uint256[]' },
          { name: 'data', internalType: 'bytes', type: 'bytes' },
        ],
      },
    ],
    name: 'mintBatchMany',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [],
    name: 'name',
    outputs: [{ name: '', internalType: 'string', type: 'string' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'pause',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [],
    name: 'paused',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [
      { name: 'role', internalType: 'bytes32', type: 'bytes32' },
      { name: 'callerConfirmation', internalType: 'address', type: 'address' },
    ],
    name: 'renounceRole',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      { name: 'role', internalType: 'bytes32', type: 'bytes32' },
      { name: 'account', internalType: 'address', type: 'address' },
    ],
    name: 'revokeRole',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      { name: 'from', internalType: 'address', type: 'address' },
      { name: 'to', internalType: 'address', type: 'address' },
      { name: 'ids', internalType: 'uint256[]', type: 'uint256[]' },
      { name: 'values', internalType: 'uint256[]', type: 'uint256[]' },
      { name: 'data', internalType: 'bytes', type: 'bytes' },
    ],
    name: 'safeBatchTransferFrom',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      { name: 'from', internalType: 'address', type: 'address' },
      { name: 'to', internalType: 'address', type: 'address' },
      { name: 'id', internalType: 'uint256', type: 'uint256' },
      { name: 'value', internalType: 'uint256', type: 'uint256' },
      { name: 'data', internalType: 'bytes', type: 'bytes' },
    ],
    name: 'safeTransferFrom',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      { name: 'operator', internalType: 'address', type: 'address' },
      { name: 'approved', internalType: 'bool', type: 'bool' },
    ],
    name: 'setApprovalForAll',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [{ name: '_name', internalType: 'string', type: 'string' }],
    name: 'setName',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [{ name: '_symbol', internalType: 'string', type: 'string' }],
    name: 'setSymbol',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [{ name: '_replaceId', internalType: 'bool', type: 'bool' }],
    name: 'setTokenUriReplaceId',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [{ name: '_newUri', internalType: 'string', type: 'string' }],
    name: 'setURI',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [{ name: '_interfaceId', internalType: 'bytes4', type: 'bytes4' }],
    name: 'supportsInterface',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'symbol',
    outputs: [{ name: '', internalType: 'string', type: 'string' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [{ name: '_account', internalType: 'address', type: 'address' }],
    name: 'tokensOfOwner',
    outputs: [
      {
        name: 'ownedTokens',
        internalType: 'struct IGildiToken.TokenBalance[]',
        type: 'tuple[]',
        components: [
          { name: 'tokenId', internalType: 'uint256', type: 'uint256' },
          { name: 'balance', internalType: 'uint256', type: 'uint256' },
        ],
      },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'totalSupply',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [{ name: '_id', internalType: 'uint256', type: 'uint256' }],
    name: 'totalSupply',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'unpause',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [{ name: '_tokenId', internalType: 'uint256', type: 'uint256' }],
    name: 'uri',
    outputs: [{ name: '', internalType: 'string', type: 'string' }],
    stateMutability: 'view',
  },
] as const
