﻿namespace Resume
{
    using System.Web.Optimization;

    public class BundleConfig
    {
        public static void RegisterBundles(BundleCollection bundles)
        {
            // javascript bundles
            bundles.Add(new ScriptBundle("~/bundles/js")
                .Include("~/Content/Scripts/app/app.min.js"));

            //style sheet bundles

            bundles.Add(new StyleBundle("~/Content/Styles/css")
                .Include("~/Content/Styles/theme.min.css"));

#if DEBUG
            // Set EnableOptimizations to false for debugging. For more information,
            // visit http://go.microsoft.com/fwlink/?LinkId=301862
            BundleTable.EnableOptimizations = false;
#else
            BundleTable.EnableOptimizations = false;
#endif
        }
    }
}