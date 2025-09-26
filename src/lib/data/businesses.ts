export interface Business {
  id: string;
  name: string;
  description: string;
  industry: string;
  totalShares: number;
  availableShares?: number;
  tokenisedSharesPercentageBps: bigint;
  pricePerShare?: number;
  marketCap: number;
  yearlyRevenue: number;
  founded: number;
  employees: string;
  location: string;
  logo: string;
  images: string[];
  keyMetrics: {
    revenueGrowth: string;
    profitMargin: string;
    debtToEquity: string;
    returnOnEquity: string;
  };
  riskLevel: 'Low' | 'Medium' | 'High';
  tokenId?: bigint;
}

export const businesses: Business[] = [
  {
    id: '1',
    name: 'GreenTech Solutions',
    description:
      'Leading provider of sustainable energy solutions for commercial buildings. Specializing in solar panel installations, energy management systems, and green building certifications.',
    industry: 'Clean Energy',
    totalShares: 1000000,
    availableShares: 250000,
    tokenisedSharesPercentageBps: 900n,
    pricePerShare: 45.5,
    marketCap: 45500000,
    yearlyRevenue: 12500000,
    founded: 2018,
    employees: '150-200',
    location: 'San Francisco, CA',
    logo: '🌱',
    images: [
      'https://images.unsplash.com/photo-1466611653911-95081537e5b7?w=800',
      'https://images.unsplash.com/photo-1497435334941-8c899ee9e8e9?w=800',
    ],
    keyMetrics: {
      revenueGrowth: '+35%',
      profitMargin: '18%',
      debtToEquity: '0.3',
      returnOnEquity: '22%',
    },
    riskLevel: 'Medium',
    tokenId: 1n,
  },
  {
    id: '2',
    name: 'FinTech Innovations',
    description:
      'Revolutionary payment processing platform serving small and medium businesses. Offering seamless integration, competitive rates, and advanced fraud protection.',
    industry: 'Financial Technology',
    totalShares: 800000,
    availableShares: 120000,
    tokenisedSharesPercentageBps: 900n,
    pricePerShare: 78.25,
    marketCap: 62600000,
    yearlyRevenue: 18200000,
    founded: 2019,
    employees: '200-250',
    location: 'New York, NY',
    logo: '💳',
    images: [
      'https://images.unsplash.com/photo-1556742049-0cfed4f6a45d?w=800',
      'https://images.unsplash.com/photo-1551288049-bebda4e38f71?w=800',
    ],
    keyMetrics: {
      revenueGrowth: '+42%',
      profitMargin: '25%',
      debtToEquity: '0.2',
      returnOnEquity: '28%',
    },
    riskLevel: 'Medium',
    tokenId: 2n,
  },
  {
    id: '3',
    name: 'HealthCare Analytics',
    description:
      'AI-powered healthcare data analytics platform helping hospitals and clinics optimize patient care and reduce costs through predictive insights.',
    industry: 'Healthcare Technology',
    totalShares: 600000,
    availableShares: 180000,
    tokenisedSharesPercentageBps: 900n,
    pricePerShare: 92.75,
    marketCap: 55650000,
    yearlyRevenue: 8900000,
    founded: 2020,
    employees: '75-100',
    location: 'Boston, MA',
    logo: '🏥',
    images: [
      'https://images.unsplash.com/photo-1559757148-5c350d0d3c56?w=800',
      'https://images.unsplash.com/photo-1576091160399-112ba8d25d1f?w=800',
    ],
    keyMetrics: {
      revenueGrowth: '+65%',
      profitMargin: '15%',
      debtToEquity: '0.1',
      returnOnEquity: '19%',
    },
    riskLevel: 'High',
    tokenId: 3n,
  },
  {
    id: '4',
    name: 'Urban Logistics',
    description:
      'Last-mile delivery optimization platform serving e-commerce businesses. Reducing delivery costs by 30% through AI-powered route optimization.',
    industry: 'Logistics & Supply Chain',
    totalShares: 1200000,
    availableShares: 300000,
    tokenisedSharesPercentageBps: 900n,
    pricePerShare: 32.1,
    marketCap: 38520000,
    yearlyRevenue: 15600000,
    founded: 2017,
    employees: '300-400',
    location: 'Austin, TX',
    logo: '📦',
    images: [
      'https://images.unsplash.com/photo-1586528116311-ad8dd3c8310d?w=800',
      'https://images.unsplash.com/photo-1566576912321-d58ddd7a6088?w=800',
    ],
    keyMetrics: {
      revenueGrowth: '+28%',
      profitMargin: '12%',
      debtToEquity: '0.4',
      returnOnEquity: '16%',
    },
    riskLevel: 'Low',
  },
  {
    id: '5',
    name: 'EduTech Platform',
    description:
      'Online learning platform specializing in professional development and certification courses. Serving over 100,000 active learners globally.',
    industry: 'Education Technology',
    totalShares: 900000,
    availableShares: 200000,
    tokenisedSharesPercentageBps: 900n,
    pricePerShare: 56.8,
    marketCap: 51120000,
    yearlyRevenue: 9800000,
    founded: 2019,
    employees: '100-150',
    location: 'Seattle, WA',
    logo: '🎓',
    images: [
      'https://images.unsplash.com/photo-1522202176988-66273c2fd55f?w=800',
      'https://images.unsplash.com/photo-1434030216411-0b793f4b4173?w=800',
    ],
    keyMetrics: {
      revenueGrowth: '+38%',
      profitMargin: '22%',
      debtToEquity: '0.2',
      returnOnEquity: '24%',
    },
    riskLevel: 'Medium',
  },
  {
    id: '6',
    name: 'AgriTech Innovations',
    description:
      'Precision agriculture technology helping farmers increase crop yields through IoT sensors, drone monitoring, and data analytics.',
    industry: 'Agricultural Technology',
    totalShares: 750000,
    availableShares: 225000,
    tokenisedSharesPercentageBps: 900n,
    pricePerShare: 41.9,
    marketCap: 31425000,
    yearlyRevenue: 6700000,
    founded: 2018,
    employees: '50-75',
    location: 'Denver, CO',
    logo: '🌾',
    images: [
      'https://images.unsplash.com/photo-1574323347407-f5e1ad6d020b?w=800',
      'https://images.unsplash.com/photo-1625246333195-78d9c38ad449?w=800',
    ],
    keyMetrics: {
      revenueGrowth: '+45%',
      profitMargin: '16%',
      debtToEquity: '0.3',
      returnOnEquity: '20%',
    },
    riskLevel: 'Medium',
  },
];
