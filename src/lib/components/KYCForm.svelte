<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import Button from './Button.svelte';

  const dispatch = createEventDispatcher();

  let currentKYCStep = 1;
  let personalInfo = {
    firstName: '',
    lastName: '',
    dateOfBirth: '',
    ssn: '',
    phone: '',
    address: '',
    city: '',
    state: '',
    zipCode: '',
    country: 'US',
  };

  let employmentInfo = {
    employmentStatus: '',
    employer: '',
    jobTitle: '',
    annualIncome: '',
    investmentExperience: '',
    riskTolerance: '',
  };

  let documentType = 'drivers_license';
  let documentsUploaded = false;

  function nextKYCStep() {
    if (currentKYCStep < 3) {
      currentKYCStep++;
    } else {
      dispatch('completed');
    }
  }

  function prevKYCStep() {
    if (currentKYCStep > 1) {
      currentKYCStep--;
    }
  }

  function handleDocumentUpload() {
    // Simulate document upload
    documentsUploaded = true;
  }
</script>

<div class="space-y-6">
  <!-- KYC Progress -->
  <div class="flex items-center justify-center space-x-4 mb-8">
    {#each [1, 2, 3] as step}
      <div
        class="w-8 h-8 rounded-full flex items-center justify-center text-sm font-semibold"
        class:bg-primary-600={step <= currentKYCStep}
        class:text-white={step <= currentKYCStep}
        class:bg-gray-300={step > currentKYCStep}
        class:text-gray-600={step > currentKYCStep}
      >
        {step}
      </div>
      {#if step < 3}
        <div
          class="w-8 h-0.5"
          class:bg-primary-600={step < currentKYCStep}
          class:bg-gray-300={step >= currentKYCStep}
        />
      {/if}
    {/each}
  </div>

  {#if currentKYCStep === 1}
    <!-- Personal Information -->
    <div>
      <h3 class="text-lg font-semibold text-gray-900 mb-4">
        Personal Information
      </h3>
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1"
            >First Name</label
          >
          <input
            type="text"
            bind:value={personalInfo.firstName}
            class="input"
            required
          />
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1"
            >Last Name</label
          >
          <input
            type="text"
            bind:value={personalInfo.lastName}
            class="input"
            required
          />
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1"
            >Date of Birth</label
          >
          <input
            type="date"
            bind:value={personalInfo.dateOfBirth}
            class="input"
            required
          />
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1"
            >Phone Number</label
          >
          <input
            type="tel"
            bind:value={personalInfo.phone}
            class="input"
            required
          />
        </div>
        <div class="md:col-span-2">
          <label class="block text-sm font-medium text-gray-700 mb-1"
            >Address</label
          >
          <input
            type="text"
            bind:value={personalInfo.address}
            class="input"
            required
          />
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1"
            >City</label
          >
          <input
            type="text"
            bind:value={personalInfo.city}
            class="input"
            required
          />
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1"
            >State</label
          >
          <input
            type="text"
            bind:value={personalInfo.state}
            class="input"
            required
          />
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1"
            >ZIP Code</label
          >
          <input
            type="text"
            bind:value={personalInfo.zipCode}
            class="input"
            required
          />
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1"
            >SSN (Last 4 digits)</label
          >
          <input
            type="text"
            bind:value={personalInfo.ssn}
            maxlength="4"
            class="input"
            required
          />
        </div>
      </div>
    </div>
  {:else if currentKYCStep === 2}
    <!-- Employment & Financial Information -->
    <div>
      <h3 class="text-lg font-semibold text-gray-900 mb-4">
        Employment & Financial Information
      </h3>
      <div class="space-y-4">
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1"
            >Employment Status</label
          >
          <select
            bind:value={employmentInfo.employmentStatus}
            class="input"
            required
          >
            <option value="">Select status</option>
            <option value="employed">Employed</option>
            <option value="self_employed">Self-employed</option>
            <option value="unemployed">Unemployed</option>
            <option value="retired">Retired</option>
            <option value="student">Student</option>
          </select>
        </div>

        {#if employmentInfo.employmentStatus === 'employed' || employmentInfo.employmentStatus === 'self_employed'}
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1"
                >Employer</label
              >
              <input
                type="text"
                bind:value={employmentInfo.employer}
                class="input"
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1"
                >Job Title</label
              >
              <input
                type="text"
                bind:value={employmentInfo.jobTitle}
                class="input"
              />
            </div>
          </div>
        {/if}

        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1"
            >Annual Income</label
          >
          <select
            bind:value={employmentInfo.annualIncome}
            class="input"
            required
          >
            <option value="">Select range</option>
            <option value="under_25k">Under $25,000</option>
            <option value="25k_50k">$25,000 - $50,000</option>
            <option value="50k_100k">$50,000 - $100,000</option>
            <option value="100k_250k">$100,000 - $250,000</option>
            <option value="250k_500k">$250,000 - $500,000</option>
            <option value="over_500k">Over $500,000</option>
          </select>
        </div>

        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1"
            >Investment Experience</label
          >
          <select
            bind:value={employmentInfo.investmentExperience}
            class="input"
            required
          >
            <option value="">Select experience</option>
            <option value="none">No experience</option>
            <option value="limited">Limited (1-2 years)</option>
            <option value="moderate">Moderate (3-5 years)</option>
            <option value="extensive">Extensive (5+ years)</option>
          </select>
        </div>

        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1"
            >Risk Tolerance</label
          >
          <select
            bind:value={employmentInfo.riskTolerance}
            class="input"
            required
          >
            <option value="">Select tolerance</option>
            <option value="conservative">Conservative</option>
            <option value="moderate">Moderate</option>
            <option value="aggressive">Aggressive</option>
          </select>
        </div>
      </div>
    </div>
  {:else if currentKYCStep === 3}
    <!-- Document Upload -->
    <div>
      <h3 class="text-lg font-semibold text-gray-900 mb-4">
        Identity Verification
      </h3>
      <p class="text-gray-600 mb-6">
        Please upload a clear photo of your government-issued ID to verify your
        identity.
      </p>

      <div class="space-y-4">
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1"
            >Document Type</label
          >
          <select bind:value={documentType} class="input">
            <option value="drivers_license">Driver's License</option>
            <option value="passport">Passport</option>
            <option value="state_id">State ID</option>
          </select>
        </div>

        <div
          class="border-2 border-dashed border-gray-300 rounded-lg p-8 text-center"
        >
          {#if !documentsUploaded}
            <div class="text-gray-400 text-4xl mb-4">📄</div>
            <p class="text-gray-600 mb-4">
              Drag and drop your document here, or click to browse
            </p>
            <Button variant="outline" on:click={handleDocumentUpload}>
              Upload Document
            </Button>
          {:else}
            <div class="text-green-500 text-4xl mb-4">✅</div>
            <p class="text-green-600 font-medium">
              Document uploaded successfully!
            </p>
            <p class="text-sm text-gray-500 mt-2">
              Your document is being reviewed. This usually takes 1-2 business
              days.
            </p>
          {/if}
        </div>

        <div class="bg-blue-50 p-4 rounded-lg">
          <h4 class="font-medium text-blue-900 mb-2">Document Requirements:</h4>
          <ul class="text-sm text-blue-800 space-y-1">
            <li>• Document must be current and not expired</li>
            <li>• All text must be clearly visible</li>
            <li>• No glare or shadows on the document</li>
            <li>• File size must be under 10MB</li>
          </ul>
        </div>
      </div>
    </div>
  {/if}

  <!-- Navigation -->
  <div class="flex justify-between pt-6 border-t border-gray-200">
    {#if currentKYCStep > 1}
      <Button variant="outline" on:click={prevKYCStep}>Back</Button>
    {:else}
      <div />
    {/if}

    <Button
      variant="primary"
      on:click={nextKYCStep}
      disabled={currentKYCStep === 3 && !documentsUploaded}
    >
      {currentKYCStep === 3 ? 'Complete Verification' : 'Continue'}
    </Button>
  </div>
</div>
