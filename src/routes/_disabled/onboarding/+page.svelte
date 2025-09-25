<script lang="ts">
  import Button from '$lib/components/Button.svelte';
  import KYCForm from '$lib/components/KYCForm.svelte';
  import { wallet, connectWallet } from '$lib/wagmi/walletStore';

  let currentStep = 1;

  const steps = [
    {
      id: 1,
      title: 'Connect Wallet',
      description: 'Link your OP Sepolia wallet to Gildi',
    },
    {
      id: 2,
      title: 'Verify Identity',
      description: 'Complete KYC verification',
    },
    {
      id: 3,
      title: 'Start Investing',
      description: 'Begin your investment journey',
    },
  ];

  function nextStep() {
    if (currentStep < steps.length) {
      currentStep += 1;
    }
  }

  function prevStep() {
    if (currentStep > 1) {
      currentStep -= 1;
    }
  }

  const handleConnectWallet = async () => {
    await connectWallet();
    if ($wallet.status === 'connected') {
      nextStep();
    }
  };

  function handleKYCComplete() {
    nextStep();
  }

  $: walletState = $wallet;
  $: isConnected = walletState.status === 'connected';
</script>

<svelte:head>
  <title>Get Started - Gildi</title>
</svelte:head>

<div class="min-h-screen bg-gray-50 py-8">
  <div class="max-w-2xl mx-auto px-4 sm:px-6 lg:px-8">
    <!-- Header -->
    <div class="text-center mb-8">
      <div class="flex justify-center mb-6">
        <img src="/Group 9 (1).png" alt="Gildi" class="h-16 w-16" />
      </div>
      <h1 class="text-3xl font-bold text-gray-900 mb-2">Welcome to Gildi</h1>
      <p class="text-gray-600">
        Let's get you started with tokenized business investments
      </p>
    </div>

    <!-- Progress Steps -->
    <div class="mb-8">
      <div class="flex items-center justify-between">
        {#each steps as step, index}
          <div
            class="flex items-center {index < steps.length - 1 ? 'flex-1' : ''}"
          >
            <div class="flex items-center">
              <div
                class="w-10 h-10 rounded-full flex items-center justify-center text-sm font-medium
                          {currentStep >= step.id
                  ? 'bg-orange-600 text-white'
                  : 'bg-gray-200 text-gray-600'}"
              >
                {step.id}
              </div>
              <div class="ml-3 hidden sm:block">
                <div class="text-sm font-medium text-gray-900">
                  {step.title}
                </div>
                <div class="text-xs text-gray-500">{step.description}</div>
              </div>
            </div>
            {#if index < steps.length - 1}
              <div class="flex-1 mx-4">
                <div
                  class="h-0.5 {currentStep > step.id
                    ? 'bg-orange-600'
                    : 'bg-gray-200'}"
                />
              </div>
            {/if}
          </div>
        {/each}
      </div>
    </div>

    <!-- Step Content -->
    <div class="bg-white rounded-xl border border-gray-200 p-8">
      {#if currentStep === 1}
        <!-- Account Creation -->
        <div class="space-y-6">
          <div class="text-center mb-6">
            <h2 class="text-2xl font-bold text-gray-900 mb-2">
              Create Your Account
            </h2>
            <p class="text-gray-600">Enter your details to get started</p>
          </div>

          <div>
            <label
              for="email"
              class="block text-sm font-medium text-gray-700 mb-1"
              >Email Address</label
            >
            <input
              id="email"
              type="email"
              bind:value={email}
              class="input"
              placeholder="Enter your email"
              required
            />
          </div>

          <div>
            <label
              for="password"
              class="block text-sm font-medium text-gray-700 mb-1"
              >Password</label
            >
            <input
              id="password"
              type="password"
              bind:value={password}
              class="input"
              placeholder="Create a strong password"
              required
            />
          </div>

          <div>
            <label
              for="confirm-password"
              class="block text-sm font-medium text-gray-700 mb-1"
              >Confirm Password</label
            >
            <input
              id="confirm-password"
              type="password"
              bind:value={confirmPassword}
              class="input"
              placeholder="Confirm your password"
              required
            />
          </div>

          <div class="flex items-start">
            <input
              id="terms"
              type="checkbox"
              bind:checked={agreedToTerms}
              class="mt-1 h-4 w-4 text-orange-600 focus:ring-orange-500 border-gray-300 rounded"
            />
            <label for="terms" class="ml-2 text-sm text-gray-600">
              I agree to the <a
                href="/terms"
                class="text-orange-600 hover:underline">Terms of Service</a
              >
              and
              <a href="/privacy" class="text-orange-600 hover:underline"
                >Privacy Policy</a
              >
            </label>
          </div>

          <Button
            variant="primary"
            class="w-full"
            disabled={!email ||
              !password ||
              !confirmPassword ||
              password !== confirmPassword ||
              !agreedToTerms}
            on:click={handleAccountCreation}
          >
            Create Account
          </Button>

          <p class="text-center text-sm text-gray-600 mt-6">
            Already have an account?
            <a href="/login" class="text-orange-600 hover:underline">Sign in</a>
          </p>
        </div>
      {:else if currentStep === 2}
        <!-- KYC Verification -->
        <div class="space-y-6">
          <div class="text-center mb-6">
            <h2 class="text-2xl font-bold text-gray-900 mb-2">
              Verify Your Identity
            </h2>
            <p class="text-gray-600">
              We need to verify your identity to comply with regulations
            </p>
          </div>

          <KYCForm on:complete={handleKYCComplete} />

          <div class="flex space-x-4">
            <Button variant="outline" class="flex-1" on:click={prevStep}>
              Back
            </Button>
          </div>
        </div>
      {:else if currentStep === 3}
        <!-- Completion -->
        <div class="text-center space-y-6">
          <div class="flex justify-center mb-6">
            <div
              class="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center"
            >
              <svg
                class="w-8 h-8 text-green-600"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M5 13l4 4L19 7"
                />
              </svg>
            </div>
          </div>

          <h2 class="text-2xl font-bold text-gray-900 mb-2">
            Welcome to Gildi!
          </h2>
          <p class="text-gray-600 mb-8">
            Your account has been created and verified. You're now ready to
            start investing in tokenized business shares.
          </p>

          <div class="space-y-4">
            <Button variant="primary" size="lg" href="/">
              Start Investing
            </Button>
            <Button variant="outline" size="lg" href="/portfolio">
              View Portfolio
            </Button>
          </div>

          <div class="mt-8 p-4 bg-orange-50 rounded-lg">
            <h3 class="font-semibold text-gray-900 mb-2">Next Steps:</h3>
            <ul class="text-sm text-gray-600 space-y-1">
              <li>• Browse available investment opportunities</li>
              <li>• Set up your investment preferences</li>
              <li>• Start building your diversified portfolio</li>
            </ul>
          </div>
        </div>
      {/if}
    </div>
  </div>
</div>
