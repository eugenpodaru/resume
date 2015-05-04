namespace Resume
{
    using System.Web.Optimization;

    public class BundleConfig
    {
        public static void RegisterBundles(BundleCollection bundles)
        {
            // javascript bundles
            bundles.Add(new ScriptBundle("~/bundles/js")
                .Include("~/Content/lib/jquery/dist/jquery.js")
                .Include("~/Content/lib/jquery-easing/jquery.easing.js")
                .Include("~/Content/lib/bootstrap/dist/js/bootstrap.js")
                .Include("~/Content/Scripts/resume.js"));

            //style sheet bundles

            bundles.Add(new StyleBundle("~/Content/Styles/css")
                .Include("~/Content/Styles/theme.css"));

#if DEBUG
            // Set EnableOptimizations to false for debugging. For more information,
            // visit http://go.microsoft.com/fwlink/?LinkId=301862
            BundleTable.EnableOptimizations = false;
#else
            BundleTable.EnableOptimizations = true;
#endif
        }
    }
}