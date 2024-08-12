/** @type { import('@storybook/react-vite').StorybookConfig } */
const config = {
  stories: [
    "../stories/**/*.mdx",
    "../stories/**/*.stories.@(js|jsx|mjs|ts|tsx)",
  ],
  addons: ["creevey"],
  framework: {
    name: "@storybook/react-vite",
    options: {},
  },
};
export default config;
