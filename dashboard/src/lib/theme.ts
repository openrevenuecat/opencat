export interface DashboardConfig {
  brandName: string;
  modules: {
    subscribers: boolean;
    revenue: boolean;
    events: boolean;
    webhooks: boolean;
    products: boolean;
    settings: boolean;
  };
}

export const defaultConfig: DashboardConfig = {
  brandName: "OpenCat",
  modules: {
    subscribers: true,
    revenue: true,
    events: true,
    webhooks: true,
    products: true,
    settings: true,
  },
};
